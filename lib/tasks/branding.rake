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
      'LOGO_THUMBNAIL' => '/brand-assets/logo_thumbnail.png',
      # The logo that would be used on the dashboard, login page etc.
      'LOGO' => '/brand-assets/logo.png',
      # The logo that would be used on the dashboard, login page etc. for dark mode
      'LOGO_DARK' => '/brand-assets/logo_dark.png',
      # The logo shown at the top of outgoing emails (PNG or JPG; email clients do not render SVG)
      'LOGO_EMAIL' => '/brand-assets/logo_email.png',
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

    skipped = []

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

      config = InstallationConfig.find_by(name: config_name)

      # A row is seeded from config/installation_config.yml by `db:chatwoot_prepare`, and this task
      # runs from the compose `post_start` hook ALONGSIDE that seeding rather than after it. On the
      # first boot of a version that introduces a name, the seed can still be in flight: measured on
      # 2026-09-09, the container started at 17:28:54 and the LOGO_EMAIL row was written at 17:29:40,
      # 46 seconds later. `find_by!` raised there, the hook exited 1, and the SEVEN names after it in
      # the list were never applied -- BRAND_COLOR among them, which stayed on the seeded upstream
      # blue across four installations while every deploy reported success.
      #
      # Skipping keeps the rest of the list and costs one boot: the next run finds the row and sets
      # it. Creating the row here instead would produce one without the display_title and description
      # that only the YAML carries, and the seed would then leave that half-row alone.
      if config.nil?
        skipped << config_name
        next
      end

      config.update!(value: value)
      puts "Updated '#{config_name}' to '#{value}'."
    end

    if skipped.any?
      puts "Not yet in the database, so left for the next run: #{skipped.join(', ')}."
    end

    puts 'Branding configuration update finished.'
  end
end
