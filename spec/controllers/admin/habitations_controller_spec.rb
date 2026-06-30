require "rails_helper"

RSpec.describe Admin::HabitationsController, type: :controller do
  describe "#apply_status_filter" do
    it "hides suspended properties when no status filter is selected" do
      active = create(:habitation, status: "Venda")
      rental = create(:habitation, status: "Aluguel")
      daily = create(:habitation, status: "Diária")
      create(:habitation, status: "Suspenso")

      result = controller.send(:apply_status_filter, Habitation.all, nil)

      expect(result).to contain_exactly(active, rental, daily)
    end

    it "does not filter by status when the all option is submitted blank" do
      active = create(:habitation, status: "Venda")
      suspended = create(:habitation, status: "Suspenso")

      result = controller.send(:apply_status_filter, Habitation.all, "", submitted: true)

      expect(result).to contain_exactly(active, suspended)
    end

    it "shows suspended properties when the suspended status filter is selected" do
      create(:habitation, status: "Venda")
      suspended = create(:habitation, status: "Suspenso")

      result = controller.send(:apply_status_filter, Habitation.all, "Suspenso")

      expect(result).to contain_exactly(suspended)
    end
  end

  describe "#can_manage_intake_status?" do
    let(:intake) { create(:habitation, :broker_intake) }

    it "permite apenas o Administrador geral" do
      admin = create(:admin_user, :admin)
      allow(controller).to receive(:current_admin_user).and_return(admin)

      expect(controller.send(:can_manage_intake_status?, intake)).to be true
    end

    it "bloqueia perfis não-admin" do
      non_admin = create(:admin_user)
      allow(controller).to receive(:current_admin_user).and_return(non_admin)

      expect(controller.send(:can_manage_intake_status?, intake)).to be_falsey
    end
  end
end
