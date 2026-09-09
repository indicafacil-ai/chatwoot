require 'rake'
require 'rails_helper'

# What an installation calls itself when nobody configures it. Worth pinning:
# these defaults sit in a file that gets merged from upstream, where the same
# keys carry the other project's name, and nothing about the merge would look
# wrong. The damage shows up in a customer's inbox, not on our screen.
RSpec.describe Rake::Task do
  describe 'branding:update' do
    subject(:task) { described_class['branding:update'] }

    # Every name the task manages, not just the five asserted on below: the task
    # walks the whole list with find_by!, so a missing row raises on a name this
    # test never looks at. A seeded database hides that — which is exactly how
    # this passed on a dev box and failed in CI.
    #
    # This list is written out rather than read from the task, so that a name
    # arriving in `configurable_items` has to be acknowledged here. Growing it
    # is the correct outcome of adding one; not noticing is not. LOGO_EMAIL and
    # BRAND_COLOR reached the task through a base update and this list did not
    # move, and the five examples below failed on a name none of them mention.
    let(:managed_names) do
      %w[
        INSTALLATION_NAME LOGO_THUMBNAIL LOGO LOGO_DARK LOGO_EMAIL BRAND_URL
        WIDGET_BRAND_URL BRAND_NAME BRAND_COLOR TERMS_URL PRIVACY_URL
        DISPLAY_MANIFEST
      ]
    end

    before do
      task.reenable
      managed_names.each { |name| InstallationConfig.find_or_create_by!(name: name) { |config| config.value = 'placeholder' } }
    end

    def config_value(name)
      InstallationConfig.find_by!(name: name).value
    end

    it 'brands the installation as this product, not as the project it is built on' do
      with_modified_env INSTALLATION_NAME: nil, BRAND_NAME: nil, BRAND_URL: nil, WIDGET_BRAND_URL: nil do
        task.invoke
      end

      expect(config_value('INSTALLATION_NAME')).to eq('IndicaFácil.AI')
      expect(config_value('BRAND_NAME')).to eq('IndicaFácil.AI')
      expect(config_value('BRAND_URL')).to eq('https://indicafacil.ai')
      expect(config_value('WIDGET_BRAND_URL')).to eq('https://indicafacil.ai')
    end

    it 'lets an instance override the brand through the environment' do
      with_modified_env BRAND_NAME: 'Agência do Cliente', BRAND_URL: 'https://cliente.com.br' do
        task.invoke
      end

      expect(config_value('BRAND_NAME')).to eq('Agência do Cliente')
      expect(config_value('BRAND_URL')).to eq('https://cliente.com.br')
    end

    # `- BRAND_NAME=${BRAND_NAME}` in a compose file whose variable was never
    # set in the panel arrives as "", and ENV.fetch would hand that straight
    # through. An instance branded as nothing at all is worse than one branded
    # upstream, because nobody reads it as a misconfiguration.
    it 'treats an empty environment variable as unset' do
      with_modified_env BRAND_NAME: '', BRAND_URL: '' do
        task.invoke
      end

      expect(config_value('BRAND_NAME')).to eq('IndicaFácil.AI')
      expect(config_value('BRAND_URL')).to eq('https://indicafacil.ai')
    end

    # The same emptiness on a boolean is not merely blank: "" is not "true", so
    # it reads as an explicit off. DISPLAY_MANIFEST off takes the new-version
    # banner down with it, which is a feature this fork added on purpose.
    it 'keeps the new-version banner on when its variable arrives empty' do
      with_modified_env DISPLAY_MANIFEST: '' do
        task.invoke
      end

      expect(config_value('DISPLAY_MANIFEST')).to be(true)
    end

    it 'still lets the banner be switched off deliberately' do
      with_modified_env DISPLAY_MANIFEST: 'false' do
        task.invoke
      end

      expect(config_value('DISPLAY_MANIFEST')).to be(false)
    end

    # THE ROW THE SEED HAS NOT WRITTEN YET. The task runs from the compose
    # `post_start` hook alongside `db:chatwoot_prepare`, not after it, so on the
    # first boot of a version that introduces a name the row can still be
    # missing. Measured on 2026-09-09: the container started at 17:28:54 and the
    # LOGO_EMAIL row landed 46 seconds later. `find_by!` raised there and the
    # SEVEN names after it were never applied, BRAND_COLOR among them -- four
    # installations kept serving the upstream blue in e-mail and on the survey
    # page while every deploy reported success.
    it 'leaves a name the seed has not written yet for the next run, and still applies the rest' do
      InstallationConfig.find_by!(name: 'LOGO_EMAIL').destroy!

      expect { task.invoke }.not_to raise_error

      # BRAND_COLOR sits after LOGO_EMAIL in the list, so it is the one the old
      # behaviour could never reach.
      expect(config_value('BRAND_COLOR')).to eq('#2162da')
      expect(InstallationConfig.exists?(name: 'LOGO_EMAIL')).to be(false)
    end
  end
end
