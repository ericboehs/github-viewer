require_relative "boot"

require "rails/all"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

# Main application namespace
module GithubViewer
  # Rails application configuration and initialization
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 8.1

    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`, for example.
    config.autoload_lib(ignore: %w[assets tasks])

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # config.time_zone = "Central Time (US & Canada)"
    # config.eager_load_paths << Rails.root.join("extras")

    # Active Record Encryption keys.
    #
    # These normally live in credentials, which production can already read via
    # RAILS_MASTER_KEY. Rails merges `config.active_record.encryption` over the
    # credentials values, so assigning nil here would blank out a perfectly good
    # credentials entry and leave every encrypted attribute unreadable. Only
    # override when the variable is actually set.
    {
      primary_key: "ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY",
      deterministic_key: "ACTIVE_RECORD_ENCRYPTION_DETERMINISTIC_KEY",
      key_derivation_salt: "ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT"
    }.each do |setting, variable|
      value = ENV[variable]
      config.active_record.encryption.public_send("#{setting}=", value) if value.present?
    end
  end
end
