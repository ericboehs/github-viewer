# Start SimpleCov before loading Rails
require "simplecov"

# SimpleCov configuration
SimpleCov.start "rails" do
  # Enable coverage for branches (Ruby 2.5+) - must come before minimum_coverage
  enable_coverage :branch

  # Set minimum coverage percentage
  minimum_coverage line: 95, branch: 95

  # Set coverage percentage precision
  minimum_coverage_by_file 90

  # Add filters for files/directories to exclude from coverage
  skip "/spec/"
  skip "/config/"
  skip "/vendor/"
  skip "/db/"
  skip "/bin/"
  skip "/test/"
  skip "app/channels/application_cable/connection.rb"
  skip "app/jobs/application_job.rb"

  # Group coverage results for better organization
  group "Controllers", "app/controllers"
  group "Models", "app/models"
  group "Services", "app/services"
  group "Jobs", "app/jobs"
  group "Helpers", "app/helpers"
  group "Mailers", "app/mailers"
  group "Channels", "app/channels"
  group "Libraries", "lib/"

  # Use Rails' default profile with some modifications
  cover "{app,lib}/**/*.rb"

  # Set up formatters
  formatter SimpleCov::Formatter::MultiFormatter.new([
    SimpleCov::Formatter::HTMLFormatter
  ])

  # Refuse to run tests if coverage drops below threshold
  refuse_coverage_drop :line, :branch

  # Maximum coverage drop allowed
  maximum_coverage_drop 5
end

ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

# Load Mocha for mocking and stubbing
require "mocha/minitest"

# Prosopite N+1 query detection (only works with PostgreSQL)
# Disabled for SQLite3 since pg_query gem is required
# require "prosopite"
# Prosopite.rails_logger = true
# Prosopite.raise = true

module ActiveSupport
  # Base class for all tests with parallel execution and coverage tracking
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Configure SimpleCov for parallel test execution
    parallelize_setup do |worker|
      SimpleCov.command_name "#{SimpleCov.command_name}-#{worker}"
    end

    parallelize_teardown do |worker|
      SimpleCov.result
    end

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # Enable Prosopite N+1 detection for each test (disabled for SQLite3)
    # setup do
    #   Prosopite.scan
    # end

    # teardown do
    #   Prosopite.finish
    # end

    # Add more helper methods to be used by all tests here...
  end
end

# Shared sign-in for integration-style tests. Every controller test used to
# define its own copy of this method.
module SignInAsIntegration
  def sign_in_as(user, password: "password123")
    post session_url, params: { email_address: user.email_address, password: password }
  end
end

ActionDispatch::IntegrationTest.include SignInAsIntegration if defined?(ActionDispatch::IntegrationTest)
