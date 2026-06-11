module SimplyCouch
  module Model
    # Bulk write helpers backed by CouchDB's `_bulk_docs` endpoint.
    #
    # DRAFT / UNVERIFIED: this code has not yet been exercised against a live
    # CouchDB instance. Review before relying on it.
    #
    # Persisting or deleting many documents one at a time is one HTTP round-trip
    # per document. `_bulk_docs` does it in a single request. These helpers map
    # onto that endpoint via CouchRest::Database#bulk_save.
    #
    # IMPORTANT — like ActiveRecord's `insert_all` / `upsert_all`, the bulk path
    # intentionally **skips model callbacks** (before/after save/create/update).
    # Timestamps are still maintained directly. If you need callbacks, save the
    # records individually. Validations run by default and can be disabled with
    # `validate: false`.
    module Bulk
      # Persist an array of records in a single request.
      # Returns a Hash: { saved: [records], invalid: [records], failed: [[record, error]] }
      def save_all(records, validate: true)
        database.bulk_save(Array(records), validate)
      end

      # Build records from an array of attribute hashes and persist them in bulk.
      def create_all(attribute_sets, validate: true)
        save_all(Array(attribute_sets).map { |attrs| new(attrs) }, validate: validate)
      end

      # Delete an array of persisted records in a single request.
      # Returns the raw `_bulk_docs` result rows.
      def destroy_all(records)
        database.bulk_destroy(Array(records))
      end
    end
  end
end
