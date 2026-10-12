class SuperAdmin::InstanceStatusesController < SuperAdmin::ApplicationController
  def show
    @metrics = {}
    chatwoot_version
    sha
    postgres_status
    redis_metrics
    chatwoot_edition
    instance_meta
    baileys_api_version
    slack_webhook_signature
  end

  # O webhook do Slack nao tem sessao nem token: a assinatura e a UNICA cerca dele. Sem
  # SLACK_SIGNING_SECRET a verificacao e pulada de proposito, para nao quebrar instalacao que
  # ja funcionava — e o aviso era uma linha de logger.warn que ninguem le. Aqui ele aparece.
  #
  # Medido: sem gancho do Slack, uma requisicao sem assinatura nao consegue nada
  # (`process_message_payload?` exige `integration_hook.present?`, e o unfurl tambem busca
  # gancho). O risco e a COMBINACAO gancho configurado + segredo ausente, e e isso que a
  # linha distingue.
  def slack_webhook_signature
    secret = GlobalConfigService.load('SLACK_SIGNING_SECRET', nil).presence || ENV.fetch('SLACK_SIGNING_SECRET', nil)
    hooks = Integrations::Hook.where(app_id: 'slack').count

    @metrics['Slack webhook signature'] = slack_signature_status(secret, hooks)
  end

  def slack_signature_status(secret, hooks)
    return 'verified' if secret.present?
    return 'not verified (no secret), but no Slack integration is connected' if hooks.zero?

    "NOT VERIFIED: #{hooks} connected Slack integration(s) accept unsigned requests. Set SLACK_SIGNING_SECRET."
  end

  def chatwoot_edition
    @metrics['Chatwoot edition'] = if ChatwootApp.enterprise?
                                     'Enterprise'
                                   elsif ChatwootApp.custom?
                                     'Custom'
                                   else
                                     'Community'
                                   end
  end

  def instance_meta
    migrations_paths = ActiveRecord::Migrator.migrations_paths
    migrations_context = ActiveRecord::MigrationContext.new(migrations_paths)
    @metrics['Database Migrations'] = migrations_context.needs_migration? ? 'pending' : 'completed'
  end

  def chatwoot_version
    @metrics['Chatwoot version'] = Chatwoot.config[:version]
  end

  def sha
    @metrics['Git SHA'] = GIT_HASH
  end

  def postgres_status
    @metrics['Postgres alive'] = if ActiveRecord::Base.connection.active?
                                   'true'
                                 else
                                   'false'
                                 end
  end

  def redis_metrics
    r = Redis.new(Redis::Config.app)
    if r.ping == 'PONG'
      redis_server = r.info
      @metrics['Redis alive'] = 'true'
      @metrics['Redis version'] = redis_server['redis_version']
      @metrics['Redis number of connected clients'] = redis_server['connected_clients']
      @metrics["Redis 'maxclients' setting"] = redis_server['maxclients']
      @metrics['Redis memory used'] = redis_server['used_memory_human']
      @metrics['Redis memory peak'] = redis_server['used_memory_peak_human']
      @metrics['Redis total memory available'] = redis_server['total_system_memory_human']
      @metrics["Redis 'maxmemory' setting"] = redis_server['maxmemory']
      @metrics["Redis 'maxmemory_policy' setting"] = redis_server['maxmemory_policy']
    end
  rescue Redis::CannotConnectError
    @metrics['Redis alive'] = false
  end

  def baileys_api_version
    @metrics['Baileys API version'] = Whatsapp::Providers::WhatsappBaileysService.status[:packageInfo][:version]
  rescue Whatsapp::Session::Errors::ProviderUnavailable => e
    @metrics['Baileys API version'] = e.message
  end
end
