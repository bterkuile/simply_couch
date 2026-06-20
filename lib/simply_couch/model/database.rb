module SimplyCouch
  module Model
    module Database
      def database
        @_simply_couch_database ||= begin
          if @_couchrest_database_url
            SimplyCouch.database_for(full_database_url)
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
  end
end
