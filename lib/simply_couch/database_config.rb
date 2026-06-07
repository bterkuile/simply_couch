# frozen_string_literal: true

module SimplyCouch
  # Global database configuration.
  #
  # Set once at boot:
  #   SimplyCouch.database_url = "http://admin:pass@localhost:5984/mozo_development"
  #
  # Override per-request (multi-tenant):
  #   SimplyCouch::Current.database = SimplyCouch.database_for("http://.../other_db")
  #
  # Fallback chain for Model#database:
  #   1. Model's own use_database / couchrest_database_url
  #   2. SimplyCouch::Current.database (request-scoped)
  #   3. SimplyCouch.database_url (global default)

  mattr_accessor :database_url

  # Returns a DatabaseInstance for the given URL, caching by URL.
  def self.database_for(url)
    return nil unless url
    databases[url] ||= Model::DatabaseInstance.new(url)
  end

  # Returns the effective default database (request-scoped or global).
  def self.database
    Current.database || database_for(database_url) || fallback_database
  end

  # Request-scoped database override for multi-tenant apps.
  class Current < ActiveSupport::CurrentAttributes
    attribute :database
  end

  private

  def self.databases
    @_databases ||= {}
  end

  def self.fallback_database
    database_for(ENV['COUCHDB_URL'] || 'http://127.0.0.1:5984/mozo_development')
  end
end
