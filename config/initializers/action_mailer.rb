ActionMailer::Base.configure do |config|
  # Use https when creating links in emails
  config.default_url_options = { protocol: 'https', host: Spree::Config[:site_url] }
end
