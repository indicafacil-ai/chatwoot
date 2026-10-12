require 'rails_helper'

RSpec.describe 'Super Admin Instance status', type: :request do
  let(:super_admin) { create(:super_admin) }

  describe 'GET /super_admin/instance_status' do
    context 'when it is an unauthenticated super admin' do
      it 'returns unauthorized' do
        get '/super_admin/instance_status'
        expect(response).to have_http_status(:redirect)
      end
    end

    context 'when it is an authenticated super admin' do
      it 'shows the instance_status page' do
        sign_in(super_admin, scope: :super_admin)
        get '/super_admin/instance_status'
        expect(response).to have_http_status(:success)
        expect(response.body).to include('Chatwoot version')
        expect(response.body).to include(GIT_HASH)
      end

      # O webhook do Slack pula a verificacao de assinatura quando o segredo falta, de
      # proposito. O aviso era um logger.warn que ninguem le; aqui ele aparece na tela,
      # e so grita quando ha gancho conectado — que e quando o pulo tem alcance.
      context 'when SLACK_SIGNING_SECRET is missing' do
        before { sign_in(super_admin, scope: :super_admin) }

        it 'says the skip has no reach without a connected Slack integration' do
          get '/super_admin/instance_status'

          expect(response.body).to include('no Slack integration is connected')
          expect(response.body).not_to include('NOT VERIFIED')
        end

        it 'warns when a connected Slack integration accepts unsigned requests' do
          create(:integrations_hook, app_id: 'slack')

          get '/super_admin/instance_status'

          expect(response.body).to include('NOT VERIFIED')
        end
      end

      it 'reports the signature as verified when the secret is set' do
        with_modified_env SLACK_SIGNING_SECRET: 'a-secret' do
          sign_in(super_admin, scope: :super_admin)
          get '/super_admin/instance_status'

          expect(response.body).to include('verified')
        end
      end
    end
  end
end
