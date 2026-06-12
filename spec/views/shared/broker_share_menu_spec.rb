require "rails_helper"

RSpec.describe "shared/_broker_share_menu", type: :view do
  before do
    allow(view).to receive(:current_admin_user).and_return(create(:admin_user))
  end

  it "renders the active share menu for a publicly viewable habitation" do
    habitation = create(:habitation, codigo: "MENU-OK", slug: "menu-compartilhavel")

    render partial: "shared/broker_share_menu", locals: { property: habitation }

    expect(rendered).to include('data-controller="broker-share"')
    expect(rendered).to include(share_link_habitation_path(habitation))
    expect(rendered).to include("Compartilhar imóvel")
    expect(rendered).not_to include("broker-share__trigger--disabled")
  end

  it "renders a disabled trigger for a habitation unavailable on the site" do
    habitation = create(:habitation, :unavailable, codigo: "MENU-NO", slug: "menu-interno")

    render partial: "shared/broker_share_menu", locals: { property: habitation }

    expect(rendered).not_to include('data-controller="broker-share"')
    expect(rendered).not_to include(share_link_habitation_path(habitation))
    expect(rendered).to include("broker-share__trigger--disabled")
    expect(rendered).to include("Publique o imóvel no site antes de compartilhar")
  end
end
