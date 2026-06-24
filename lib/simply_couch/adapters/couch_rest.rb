# frozen_string_literal: true

require 'couchrest'
require 'json'

# CouchRest decodes documents straight into model objects: it parses JSON with
# create_additions enabled and uses the 'ruby_class' tag to pick the class (each
# model defines .json_create). These two globals are what make that work, so
# they live with the CouchRest adapter rather than in backend-neutral core.
CouchRest.decode_json_objects = true
JSON.create_id = 'ruby_class'

module SimplyCouch
  module Adapters
    # The default backend: Apache CouchDB over the couchrest driver.
    #
    # This holds the persistence logic that used to live in
    # SimplyCouch::Model::DatabaseInstance — moved verbatim behind the
    # SimplyCouch::Adapter contract so the model layer no longer names couchrest.
    class CouchRest < SimplyCouch::Adapter
      # CouchDB-native inline attachments (see Model::Attachment::Couch) reach the
      # raw driver through this reader. It is an adapter-specific extension, NOT
      # part of the neutral contract — backends without it (couchbase) simply do
      # not respond to it, and the attachment code guards with respond_to?.
      attr_reader :couchrest_database

      def initialize(couchrest_database = nil)
        if couchrest_database.is_a?(String)
          @couchrest_database = ::CouchRest.database(couchrest_database)
        elsif couchrest_database.nil?
          @couchrest_database = ::CouchRest.database('http://127.0.0.1:5984')
        else
          @couchrest_database = couchrest_database
        end
      end

      def view(spec)
        results = Model::View::ViewQuery.new(
          couchrest_database,
          spec.design_document,
          {spec.view_name => {
            :map => spec.map_function,
            :reduce => spec.reduce_function
          }},
          (spec.list_name ? {spec.list_name => spec.list_function} : nil),
          spec.lib,
          spec.language
        ).query_view!(spec.view_parameters)
        processed_results = spec.process_results results
        processed_results.each do |document|
          document.database = self if document.respond_to?(:database=)
        end if processed_results.respond_to?(:each)
        processed_results
      end

      def first(spec)
        spec.view_parameters = spec.view_parameters.merge({:limit => 1})
        view(spec).first
      end

      def save_document(document, validate = true)
        begin
          if document.new?
            create_document(document, validate)
          else
            update_document(document, validate)
          end
        rescue ::CouchRest::Conflict
          raise SimplyCouch::Conflict.new
        end
      end

      def load_document(id)
        raise "Can't load a document without an id (got nil)" if id.nil?
        instance = couchrest_database.get(id)
        instance.database = self if instance.respond_to?(:database=)
        instance
      end

      def destroy_document(document, run_callbacks = true)
        if run_callbacks
          document.run_callbacks :destroy do
            document._deleted = true
            couchrest_database.delete_doc document.to_hash
          end
        else
          document._deleted = true
          couchrest_database.delete_doc document.to_hash
        end
        document._id = nil
        document._rev = nil
      end

      def bulk_load(ids)
        ids = Array(ids).compact
        return [] if ids.empty?
        response = couchrest_database.bulk_load ids
        docs = response['rows'].map{|row| row["doc"]}.compact
        docs.each{|doc| doc.database = self if doc.respond_to?(:database=) }
        docs
      end

      # Persist many documents via CouchDB's _bulk_docs endpoint in one request.
      # Callbacks are intentionally skipped (see SimplyCouch::Model::Bulk);
      # timestamps are maintained directly. Returns
      #   { saved: [...], invalid: [...], failed: [[doc, error], ...] }
      def bulk_save(documents, validate = true)
        documents = Array(documents)
        return { saved: [], invalid: [], failed: [] } if documents.empty?

        invalid    = []
        persisting = []
        payload    = []
        now        = Time.now

        documents.each do |document|
          document.database = self
          document.created_at ||= now if document.respond_to?(:created_at) && document.new?
          document.updated_at   = now if document.respond_to?(:updated_at=)

          if validate
            document.errors.clear
            unless valid_document?(document)
              invalid << document
              next
            end
          end

          persisting << document
          payload    << document.to_hash
        end

        return { saved: [], invalid: invalid, failed: [] } if payload.empty?

        rows   = Array(couchrest_database.bulk_save(payload))
        saved  = []
        failed = []

        persisting.each_with_index do |document, i|
          row = rows[i]
          if row && row['error']
            failed << [document, row['error']]
          else
            document._id  = row['id']  if row && row['id']
            document._rev = row['rev'] if row && row['rev']
            document.send(:clear_changes_information) if document.respond_to?(:clear_changes_information, true)
            saved << document
          end
        end

        { saved: saved, invalid: invalid, failed: failed }
      end

      # Delete many persisted documents via _bulk_docs in one request.
      # Returns the raw result rows; clears _id/_rev on the passed records.
      def bulk_destroy(documents)
        documents = Array(documents)
        return [] if documents.empty?
        payload = documents.map { |d| { '_id' => d._id, '_rev' => d._rev, '_deleted' => true } }
        rows = Array(couchrest_database.bulk_save(payload))
        documents.each { |d| d._id = nil; d._rev = nil }
        rows
      end

      def delete_document(document)
        couchrest_database.delete_doc document.to_hash
      end

      # --- admin (test / rake) ------------------------------------------------

      def create_database!
        couchrest_database.create!
        self
      rescue ::CouchRest::PreconditionFailed
        self # already exists
      end

      def drop_database!
        couchrest_database.delete!
      rescue ::CouchRest::NotFound
        nil # already absent
      end

      # Remove every _design document from a database (rake helper).
      def self.delete_all_design_documents(database)
        db = ::CouchRest.database(database)
        db.info # ensure DB exists
        design_docs = ::CouchRest.get("#{database}/_all_docs?startkey=%22_design%22&endkey=%22_design0%22")['rows'].map do |row|
          [row['id'], row['value']['rev']]
        end
        design_docs.each do |doc_id, rev|
          db.delete_doc({'_id' => doc_id, '_rev' => rev})
        end
        design_docs.size
      end

      # Compact every _design document in a database (rake helper).
      def self.compact_all_design_documents(database)
        db = ::CouchRest.database(database)
        db.info # ensure DB exists
        design_docs = ::CouchRest.get("#{database}/_all_docs?startkey=%22_design%22&endkey=%22_design0%22")['rows'].map do |row|
          [row['id'], row['value']['rev']]
        end
        design_docs.each do |doc_id, rev|
          puts "#{database}/_compact/#{doc_id.gsub("_design/",'')}"
          ::CouchRest.post("#{database}/_compact/#{doc_id.gsub("_design/",'')}")
        end
        design_docs.size
      end

      private

      def create_document(document, validate)
        document.database = self
        if validate
          document.errors.clear
          return false if false == document.run_callbacks(:validation) do
            return false if false == document.run_callbacks(:validation_on_create) do
              return false unless valid_document?(document)
            end
          end
        end
        return false if false == document.run_callbacks(:save) do
          return false if false == document.run_callbacks(:create) do
            res = couchrest_database.save_doc document.to_hash
            document._rev = res['rev']
            document._id = res['id']
          end
        end
        true
      end

      def update_document(document, validate)
        if validate
          document.errors.clear
          return false if false == document.run_callbacks(:validation) do
            return false if false == document.run_callbacks(:validation_on_update) do
              return false unless valid_document?(document)
            end
          end
        end
        return false if false == document.run_callbacks(:save) do
          return false if false == document.run_callbacks(:update) do
            if document.changed?
              res = couchrest_database.save_doc document.to_hash
              document._rev = res['rev']
            end
          end
        end
        true
      end

      def valid_document?(document)
        original_errors_hash = document.errors.to_hash
        document.valid?
        original_errors_hash.each do |k, v|
          if v.respond_to?(:each)
            v.each {|message| document.errors.add(k, message)}
          else
            document.errors.add(k, v)
          end
        end
        document.errors.empty?
      end
    end
  end
end

# Back-compat: external code referencing the old class name keeps working under
# the couchrest backend. New code should depend on the SimplyCouch::Adapter
# contract, not this constant.
SimplyCouch::Model::DatabaseInstance = SimplyCouch::Adapters::CouchRest
