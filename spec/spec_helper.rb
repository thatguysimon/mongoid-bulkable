require "bundler/setup"
require "mongoid"
require "mongoid/bulkable"

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = ".rspec_status"

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end
end


ENV['MONGOID_ENV'] = "test"
Mongoid.load!(File.expand_path("../mongoid.yml", __FILE__), :test)
Mongo::Logger.logger.level = ::Logger::INFO
