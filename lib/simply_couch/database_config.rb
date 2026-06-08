# frozen_string_literal: true

require 'active_support/core_ext/module/attribute_accessors'

module SimplyCouch
  # Global CouchDB configuration.
  #
  # Set once at boot:
  #   SimplyCouch.database_url = "http://admin:pass@localhost:5984/mozo_development"
  #
  # Per-request override (multi-tenant):
  #   Define a top-level Current class in your app:
  #
  #     class Current < ActiveSupport::CurrentAttributes
  #       attribute :couch_database
  #     end
  #
  #   Then set it per-request (e.g. in ApplicationController):
  #     Current.couch_database = SimplyCouch.database_for("http://.../company_x")
  #
  # Block-scoped:
  #   SimplyCouch.with_database(db) { ... }
  #
  # Fallback chain for Model#database:
  #   1. Model's own use_database / couchrest_database_url
  #   2. Current.couch_database (app-defined, request-scoped)
  #   3. SimplyCouch.database_url (global default)

  mattr_accessor :database_url
  mattr_accessor :s3_defaults

  # Load S3 defaults from a YAML config file with ERB support.
  #   SimplyCouch.load_s3_config(Rails.root.join('config', 's3.yml'))
  #
  # Supports Rails credentials directly:
  #   SimplyCouch.s3_defaults = Rails.application.credentials.s3
  def self.load_s3_config(path, env = nil)
    env ||= defined?(Rails) ? Rails.env : 'development'
    raw = File.read(path.to_s)
    yaml = defined?(ERB) ? ERB.new(raw).result : raw
    config = YAML.safe_load(yaml, permitted_classes: [], permitted_symbols: [], aliases: true) || {}
    self.s3_defaults = (config[env] || {}).deep_symbolize_keys
  end

  # Returns a DatabaseInstance for the given URL, caching by URL.
  def self.database_for(url)
    return nil unless url
    databases[url] ||= Model::DatabaseInstance.new(url)
  end

  # Returns the effective default database (request-scoped or global).
  def self.database
    current_database || database_for(database_url) || fallback_database
  end

  # Temporarily switch the current database for a block.
  def self.with_database(database)
    previous = current_database
    self.current_database = database
    yield
  ensure
    self.current_database = previous
  end

  # Get/set the request-scoped database (delegates to app's Current class).
  def self.current_database
    defined?(::Current) && ::Current.respond_to?(:couch_database) ? ::Current.couch_database : nil
  end

  def self.current_database=(db)
    ::Current.couch_database = db if defined?(::Current) && ::Current.respond_to?(:couch_database=)
  end

  private

  def self.databases
    @_databases ||= {}
  end

  def self.fallback_database
    database_for(ENV['COUCHDB_URL'] || 'http://127.0.0.1:5984/mozo_development')
  end
end
