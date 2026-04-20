require 'rails_helper'

RSpec.describe Leads::DistributorService do
  let(:store) { create(:store) }
  let(:agent_with_checkin) { create(:admin_user, :field_agent) }
  let(:agent_without_checkin) { create(:admin_user, :field_agent) }

  before do
    # agent_with_checkin tem check-in ativo na loja
    create(:check_in, admin_user: agent_with_checkin, store: store, status: :active, checked_in_at: 5.minutes.ago)
    # Testamos DistributorService em isolação, sem o callback after_create_commit
    Lead.skip_callback(:commit, :after, :route_lead)
  end

  after { Lead.set_callback(:commit, :after, :route_lead) }

  def build_lead(attrs = {})
    Lead.create!(attrs.reverse_merge(name: "Cliente Teste", phone: "11999999999", origin: "site"))
  end

  describe "retrocompatibilidade (flags default off)" do
    it "distribui normalmente quando regra não exige check-in, mesmo sem corretor logado" do
      rule = create(:distribution_rule, require_active_checkin: false)
      create(:distribution_rule_agent, distribution_rule: rule, admin_user: agent_without_checkin)

      lead = build_lead
      described_class.find_and_distribute(lead)

      expect(lead.reload.admin_user_id).to eq(agent_without_checkin.id)
      expect(lead.status).to eq("waiting_acceptance")
    end
  end

  describe "require_active_checkin=true" do
    it "entrega lead apenas para corretor com check-in ativo" do
      rule = create(:distribution_rule, require_active_checkin: true)
      create(:distribution_rule_agent, distribution_rule: rule, admin_user: agent_without_checkin)
      create(:distribution_rule_agent, distribution_rule: rule, admin_user: agent_with_checkin)

      lead = build_lead
      described_class.find_and_distribute(lead)

      expect(lead.reload.admin_user_id).to eq(agent_with_checkin.id)
    end

    it "filtra por checkin_store_id quando setado" do
      outra_loja = create(:store, name: "Outra")
      rule = create(:distribution_rule, require_active_checkin: true, checkin_store_id: outra_loja.id)
      create(:distribution_rule_agent, distribution_rule: rule, admin_user: agent_with_checkin)

      lead = build_lead
      described_class.find_and_distribute(lead)

      # agent_with_checkin está na loja `store`, não em `outra_loja` → não elegível
      expect(lead.reload.admin_user_id).to be_nil
    end

    context "sem candidatos elegíveis + represamento_active" do
      it "deixa lead represado com razão no_eligible_agent_with_checkin" do
        rule = create(:distribution_rule,
                      require_active_checkin: true,
                      represamento_active: true)
        create(:distribution_rule_agent, distribution_rule: rule, admin_user: agent_without_checkin)

        lead = build_lead
        described_class.find_and_distribute(lead)

        lead.reload
        expect(lead.status).to eq("represado")
        activity = lead.activities.where(kind: "dammed").last
        expect(activity).to be_present
        expect(activity.metadata["reason"]).to eq("no_eligible_agent_with_checkin")
      end
    end
  end

  describe "DistributionRule#candidates_filtered_by_checkin" do
    it "retorna todos os agentes quando flag off (retrocompat)" do
      rule = create(:distribution_rule, require_active_checkin: false)
      dra1 = create(:distribution_rule_agent, distribution_rule: rule, admin_user: agent_with_checkin)
      dra2 = create(:distribution_rule_agent, distribution_rule: rule, admin_user: agent_without_checkin)

      expect(rule.candidates_filtered_by_checkin.pluck(:id)).to match_array([dra1.id, dra2.id])
    end

    it "filtra apenas agents com check-in ativo quando flag on" do
      rule = create(:distribution_rule, require_active_checkin: true)
      dra1 = create(:distribution_rule_agent, distribution_rule: rule, admin_user: agent_with_checkin)
      create(:distribution_rule_agent, distribution_rule: rule, admin_user: agent_without_checkin)

      expect(rule.candidates_filtered_by_checkin.pluck(:id)).to eq([dra1.id])
    end
  end
end
