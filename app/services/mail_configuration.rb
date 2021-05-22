# Configures Rails to use the specified mail configuration
#
# Mail auth types: 'None', 'plain', 'login', 'cram_md5'
# Secure connection types: 'None', 'SSL', 'TLS'
#
class MailConfiguration
  def self.apply!
    new.configure_actionmailer!
  end

  def configure_actionmailer!
    ActionMailer::Base.default_url_options[:host] ||= Spree::Config.site_url
    ActionMailer::Base.smtp_settings = mail_server_settings
    ActionMailer::Base.perform_deliveries = true
  end

  private

  def mail_server_settings
    settings = if need_authentication?
                 basic_settings.merge(user_credentials)
               else
                 basic_settings
               end

    settings.merge(enable_starttls_auto: secure_connection?)
  end

  def user_credentials
    { user_name: ENV.fetch('SMTP_USERNAME', nil),
      password: ENV.fetch('SMTP_PASSWORD', nil) }
  end

  def basic_settings
    { address: ENV.fetch('MAIL_HOST', 'localhost'),
      domain: ENV.fetch('MAIL_DOMAIN', 'localhost'),
      port: ENV.fetch('MAIL_PORT', 25),
      authentication: ENV.fetch('MAIL_AUTH_TYPE', 'login') }
  end

  def need_authentication?
    ENV.fetch('MAIL_AUTH_TYPE', 'login') != 'None'
  end

  def secure_connection?
    ENV.fetch('MAIL_SECURE_CONNECTION', 'None') == 'TLS'
  end
end
