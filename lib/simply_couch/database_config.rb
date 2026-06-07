# frozen_string_literal: true

module SimplyCouch
  # Global CouchDB configuration.
  #
  # Set once at boot:
  #   SimplyCouch.database_url = "http://admin:pass@localhost:5984/mozo_development"
  #
  # Override per-request (multi-tenant):
  #   SimplyCouch::Current.couch_database = SimplyCouch.couch_database_for("http://.../other_db")
  #
  # Block-scoped:
  #   SimplyCouch.with_couch_database(db) { ... }
  #
  # Fallback chain for Model#couch_database:
  #   1. Model's own use_database / couchrest_database_url
  #   2. SimplyCouch::Current.couch_database (request-scoped)
  #   3. SimplyCouch.database_url (global default)

  mattr_accessor :database_url

  # Returns a DatabaseInstance for the given URL, caching by URL.
  def self.couch_database_for(url)
    return nil unless url
    databases[url] ||= Model::DatabaseInstance.new(url)
  end

  # Returns the effective default database (request-scoped or global).
  def self.couch_database
    Current.couch_database || couch_database_for(database_url) || fallback_couch_database
  end

  # Request-scoped database override for multi-tenant apps.
  class Current < ActiveSupport::CurrentAttributes
    attribute :couch_database
  end

  # Temporarily switch the current database for a block.
  # Resets to the previous database afterward.
  #
  #   SimplyCouch.with_couch_database(my_db) do
  #     Post.all  # queries my_db
  #   end
  #   Post.all      # back to default
  def self.with_couch_database(database)
    previous = Current.couch_database
    Current.couch_database = database
    yield
  ensure
    Current.couch_database = previous
  end

  private

  def self.couch_databases
    @_databases ||= {}
  end

  def self.fallback_couch_database
    couch_database_for(ENV['COUCHDB_URL'] || 'http://127.0.0.1:5984/mozo_development')
  end
end
