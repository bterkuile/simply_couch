require 'pry'
require 'couchrest'
require 'simply_couch'
require 'fixtures/couch'

COUCHDB_URL = "http://admin:#{ENV['COUCHDB_ADMIN_PASSWORD']}@127.0.0.1:5984"
TEST_DB = 'simply_couch_test'

Dir.glob("spec/support/**/*.rb").each {|f| require f.sub(/^spec\//, '')}

RSpec.configure do |config|
  config.expect_with(:rspec) { |c| c.syntax = [:expect, :should] }
  config.color = true
  config.tty = true

  config.before(:each) do
    $performed_queries = []
    server = CouchRest.new(COUCHDB_URL)
    begin
      server.database(TEST_DB).delete!
    rescue StandardError
      # database doesn't exist or already deleted
    end
    begin; server.create_db(TEST_DB); rescue CouchRest::PreconditionFailed, CouchRest::PreconditionFailed, CouchRest::NotFound; end
    SimplyCouch::Model::Database.class_eval do
    SimplyCouch.database_url = "#{COUCHDB_URL}/#{TEST_DB}"
      define_method(:couchrest_database_url) { "#{COUCHDB_URL}/#{TEST_DB}" }
    end
  end
end
