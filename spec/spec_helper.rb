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
    SimplyCouch::Model::View::ViewQuery.clear_cache

    SimplyCouch.database_url = "#{COUCHDB_URL}/#{TEST_DB}"
    SimplyCouch::Model::Database.class_eval do
      define_method(:couchrest_database_url) { "#{COUCHDB_URL}/#{TEST_DB}" }
    end

    # Reset the test database through the adapter contract — the harness no
    # longer talks to a driver directly, so it works for any backend.
    db = SimplyCouch.database_for("#{COUCHDB_URL}/#{TEST_DB}")
    db.drop_database!
    db.create_database!
  end
end
