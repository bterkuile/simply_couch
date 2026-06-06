require 'pry'
require 'couchrest'
require 'simply_stored'
require 'fixtures/couch'

COUCHDB_URL = "http://admin:#{ENV['COUCHDB_ADMIN_PASSWORD']}@127.0.0.1:5984"
TEST_DB = 'simply_stored_test'

Dir.glob("spec/support/**/*.rb").each {|f| require f.sub(/^spec\//, '')}

RSpec.configure do |config|
  config.expect_with(:rspec) { |c| c.syntax = [:expect, :should] }
  config.color = true
  config.tty = true

  config.before(:each) do
    $performed_queries = []
    server = CouchRest.new(COUCHDB_URL)
    begin
      db = server.database(TEST_DB)
      db.delete!
    rescue CouchRest::NotFound, CouchRest::PreconditionFailed
    end
    server.create_db(TEST_DB)
    SimplyStored::Couch::Database.class_eval do
      define_method(:couchrest_database_url) { "#{COUCHDB_URL}/#{TEST_DB}" }
    end
  end
end
