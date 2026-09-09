# NOTE: See https://github.com/indicafacil-ai/chatwoot/blob/main/CUSTOM_BRANDING.md for more details.
namespace :branding do
  desc 'Updates branding configurations from environment variables or defaults'
  task update: :environment do
    # These are the defaults of *this* product, not of the project it is built
    # on. They are what an installation shows when nobody sets a single
    # environment variable — which is every installation, because ten variables
    # is nine more than anyone remembers to fill in. An instance that needs its
    # own brand still overrides any of them through the environment.
    #
    # Leaving the upstream values here is not a cosmetic slip: the "Powered by"
    # in every e-mail this instance sends to a customer's own customers, and the
    # one in the chat widget on their site, pointed at another company.
    configurable_items = {
      # The installation wide name that would be used in the dashboard, title etc.
      'INSTALLATION_NAME' => 'IndicaFácil.AI',
      # The thumbnail that would be used for favicon (512px X 512px)
      'LOGO_THUMBNAIL' => '/brand-assets/logo_thumbnail.svg',
      # The logo that would be used on the dashboard, login page etc.
      'LOGO' => '/brand-assets/logo.svg',
      # The logo that would be used on the dashboard, login page etc. for dark mode
      'LOGO_DARK' => '/brand-assets/logo_dark.svg',
      # The logo shown at the top of outgoing emails (PNG or JPG; email clients do not render SVG)
      'LOGO_EMAIL' => '',
      # The URL that would be used in emails under the section “Powered By”
      'BRAND_URL' => 'https://indicafacil.ai',
      # The URL that would be used in the widget under the section “Powered By”
      'WIDGET_BRAND_URL' => 'https://indicafacil.ai',
      # The name that would be used in emails and the widget
      'BRAND_NAME' => 'IndicaFácil.AI',
      # Hex colour used in emails and for the PWA theme (example: #1f93ff)
      'BRAND_COLOR' => '#2162da',
      # The terms of service URL displayed in Signup Page
      'TERMS_URL' => 'https://www.chatwoot.com/terms-of-service',
      # The privacy policy URL displayed in the app
      'PRIVACY_URL' => 'https://www.chatwoot.com/privacy-policy',
      # Display default Chatwoot metadata like favicons and upgrade warnings
      'DISPLAY_MANIFEST' => true
    }

    configurable_items.each do |config_name, default_value|
      # Blank counts as absent. `- BRAND_NAME=${BRAND_NAME}` in a compose file
      # whose variable was never set in the panel reaches the container as an
      # empty string, and ENV.fetch finds the key and hands that back — the
      # brand would come out blank rather than defaulted. DISPLAY_MANIFEST is
      # worse: "" is not "true", so it would silently switch off the
      # new-version banner. This project has already been bitten once by an
      # undeclared BRAND_ASSETS_URL arriving empty.
      from_env = ENV[config_name].presence

      value = if default_value.in?([true, false])
                from_env.nil? ? default_value : from_env == 'true'
              else
                from_env || default_value
              end

      InstallationConfig.find_by!(name: config_name).update!(value: value)
      puts "Updated '#{config_name}' to '#{value}'."
    end

    puts 'Branding configuration update finished.'
  end
end
