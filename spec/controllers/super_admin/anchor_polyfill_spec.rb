require 'rails_helper'

# O Administrate 1.0 roda o polyfill de CSS anchor positioning em toda carga e troca os
# <link> de CSS por blob: -- as fontes (caminho relativo) quebram e o painel pisca. A
# opcao que o poe para dormir precisa vir ANTES do JS do Administrate, senao ele ja rodou.
RSpec.describe 'Super Admin anchor polyfill', type: :request do
  let(:super_admin) { create(:super_admin) }

  it 'declares the polyfill opt-out before the Administrate bundle is loaded' do
    sign_in(super_admin, scope: :super_admin)
    get '/super_admin/instance_status'

    opt_out = response.body.index('ANCHOR_POSITIONING_POLYFILL_OPTIONS = { elements: [] }')
    bundle = response.body.index(%r{<script[^>]+src="[^"]*administrate/application[^"]*\.js"})

    expect(opt_out).to be_present
    expect(bundle).to be_present
    expect(opt_out).to be < bundle
  end
end
