module SimplyCouch
  module Model
    module Database
      def database
        @_simply_couch_database ||= begin
          if @_couchrest_database_url
            DatabaseInstance.new(full_database_url)
          else
            SimplyCouch.database
          end
        end
      end

      # Override this to provide a custom database URL.
      # In Rails, reads config/couchdb.yml automatically.
      def couchrest_database_url
        @_couchrest_database_url || detect_couchdb_url || ENV['COUCHDB_URL'] || 'http://127.0.0.1:5984'
      end

      def couchrest_database_url=(url)
        @_couchrest_database_url = url
      end

      private

      def full_database_url
        base = couchrest_database_url
        name = database_name
        # Only append db name if URL doesn't already include it.
        # Skip URL scheme slashes (http://) when checking for existing db name.
        path_part = base.sub(%r{^https?://}, '')
        if path_part.include?('/')
          base  # URL already has a database name
        else
          "#{base}/#{name}"
        end
      end

      def database_name
        @_database_name || detect_database_name || 'mozo_development'
      end

      def database_name=(name)
        @_database_name = name
      end

      def detect_couchdb_url
        return unless defined?(Rails) && Rails.root
        config_path = Rails.root.join('config/couchdb.yml')
        return unless File.exist?(config_path)
        config = YAML.safe_load(ERB.new(File.read(config_path)).result, permitted_classes: [Symbol])
        env_config = config[Rails.env] || config['development']
        db_url = env_config['database'] if env_config.is_a?(Hash)
        # Extract host:port from full URL like http://admin:pass@host:port/dbname
        # Strip database name from full URL, skipping URL scheme
        db_url&.sub(%r{/([^/]+)$}, '') { $1 if $1.include?('.') || $1.length < 15 }
      end

      def detect_database_name
        return unless defined?(Rails) && Rails.root
        config_path = Rails.root.join('config/couchdb.yml')
        return unless File.exist?(config_path)
        config = YAML.safe_load(ERB.new(File.read(config_path)).result, permitted_classes: [Symbol])
        env_config = config[Rails.env] || config['development']
        db_url = env_config['database'] if env_config.is_a?(Hash)
        return unless db_url
        URI.parse(db_url).path&.sub('/', '')
      end
    end

    # Renamed from CompatibilityNote — this is the actual Database class
    # (separate from the Database module above to avoid naming conflict)
    class DatabaseInstance
      attr_reader :couchrest_database

      def initialize(couchrest_database)
        if couchrest_database.is_a?(String)
          # URL string — create CouchRest database
          @couchrest_database = CouchRest.couch_database(couchrest_database)
        elsif couchrest_database.nil?
          @couchrest_database = CouchRest.couch_database('http://127.0.0.1:5984')
        else
          @couchrest_database = couchrest_database
        end
      end

      def view(spec)
        results = View::ViewQuery.new(
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
          document.couch_database = self if document.respond_to?(:database=)
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
        rescue CouchRest::Conflict
          raise SimplyCouch::Conflict.new
        end
      end

      def save_document!(document)
        save_document(document) || raise("Validations failed: #{document.errors.full_messages}")
      end

      def load_document(id)
        raise "Can't load a document without an id (got nil)" if id.nil?
        instance = couchrest_database.get(id)
        instance.couch_database = self if instance.respond_to?(:database=)
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
        response = couchrest_database.bulk_load ids
        docs = response['rows'].map{|row| row["doc"]}.compact
        docs.each{|doc| doc.couch_database = self if doc.respond_to?(:database=) }
        docs
      end

      def delete_document(document)
        couchrest_database.delete_doc document.to_hash
      end

      private

      def create_document(document, validate)
        document.couch_database = self
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
