# frozen_string_literal: true

module SimplyCouch
  # Backend-neutral persistence contract.
  #
  # The model layer (finders, persistence, associations, views) only ever talks
  # to an object of this shape — it never names a concrete driver. A backend is
  # a subclass that implements these methods and registers itself via
  #   SimplyCouch.register_adapter(:name, "SimplyCouch::Adapters::Foo",
  #                                require_path: "simply_couch/adapters/foo")
  #
  # Exception contract: implementations MUST translate backend-native errors into
  #   - SimplyCouch::Conflict  (optimistic-concurrency clash on save)
  #   - SimplyCouch::NotFound  (where applicable)
  # so the model layer never rescues a driver-specific class.
  #
  # The default backend is :couchrest (CouchDB). The couchbase backend ships as
  # the separate `simply_couch-couchbase` gem.
  #
  # Each adapter is constructed with a single connection argument (a URL string
  # for CouchDB; a connection spec for other backends) and is cached per-URL by
  # SimplyCouch.database_for.
  class Adapter
    def initialize(_connection = nil)
      # subclasses establish their connection here
    end

    # --- single document ------------------------------------------------------

    # Persist (create or update) a model, running its callbacks/validations.
    # Returns true on success, false when validations halt the save.
    # Raises SimplyCouch::Conflict on an optimistic-concurrency clash.
    def save_document(document, validate = true)
      raise SimplyCouch::NotImplementedError, "#{self.class}#save_document"
    end

    # Save or raise. Shared default — subclasses rarely override.
    def save_document!(document)
      save_document(document) || raise("Validations failed: #{document.errors.full_messages}")
    end

    # Load one document by id, reconstructed into its model class.
    # Returns nil when the id does not exist (the model layer turns that into
    # SimplyCouch::RecordNotFound). Must NOT raise on a plain miss.
    def load_document(id)
      raise SimplyCouch::NotImplementedError, "#{self.class}#load_document"
    end

    # Delete a model, running :destroy callbacks unless told otherwise, and clear
    # its _id/_rev.
    def destroy_document(document, run_callbacks = true)
      raise SimplyCouch::NotImplementedError, "#{self.class}#destroy_document"
    end

    # Low-level delete with no callbacks.
    def delete_document(document)
      raise SimplyCouch::NotImplementedError, "#{self.class}#delete_document"
    end

    # --- queries --------------------------------------------------------------

    # Run a structured view spec (a SimplyCouch::Model::View::*Spec) and return
    # the processed results. Each backend decides HOW to satisfy it (CouchDB
    # design-doc map/reduce, Couchbase N1QL + GSI, …). The spec is the
    # backend-neutral query IR — see lib/simply_couch/model/view*/.
    def view(spec)
      raise SimplyCouch::NotImplementedError, "#{self.class}#view"
    end

    # The first result of a view spec (adapters usually limit to 1).
    def first(spec)
      raise SimplyCouch::NotImplementedError, "#{self.class}#first"
    end

    # --- bulk -----------------------------------------------------------------

    # Load many ids in one round-trip. Returns an Array of model docs with
    # missing ids dropped; each returned doc has #database assigned to self.
    def bulk_load(ids)
      raise SimplyCouch::NotImplementedError, "#{self.class}#bulk_load"
    end

    # Persist many documents in one round-trip, skipping per-document callbacks
    # (timestamps are still maintained). Returns
    #   { saved: [...], invalid: [...], failed: [[doc, error], ...] }
    def bulk_save(documents, validate = true)
      raise SimplyCouch::NotImplementedError, "#{self.class}#bulk_save"
    end

    # Delete many persisted docs in one round-trip; clears _id/_rev on each.
    def bulk_destroy(documents)
      raise SimplyCouch::NotImplementedError, "#{self.class}#bulk_destroy"
    end

    # --- admin (test / rake) --------------------------------------------------

    # Create the backing database/bucket. Idempotent (no error if it exists).
    def create_database!
      raise SimplyCouch::NotImplementedError, "#{self.class}#create_database!"
    end

    # Drop the backing database/bucket. Idempotent (no error if it is absent).
    def drop_database!
      raise SimplyCouch::NotImplementedError, "#{self.class}#drop_database!"
    end
  end
end
