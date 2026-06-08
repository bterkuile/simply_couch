# frozen_string_literal: true

module SimplyCouch
  module Model
    module Attachment
      # CouchDB inline attachments — declarative, lazy-loaded.
      #
      # Two levels of API:
      #
      #   1. Low-level (instance methods):
      #      put_couch_attachment(name, data, content_type: 'image/png')
      #      fetch_couch_attachment(name)
      #      delete_couch_attachment(name)
      #
      #   2. High-level (class macro):
      #      has_couch_attached :invoice
      #
      #      record.invoice = File.read('invoice.pdf')   # auto-detects content_type
      #      record.invoice                               # fetches binary data
      #      record.invoice_content_type                  # => 'application/pdf'
      #      record.invoice_size                          # => 24501
      #
      module Couch
        def self.included(base)
          base.after_save :_save_pending_couch_attachments
        end

        # ── Low-level instance methods ──────────────────────────────────

        def put_couch_attachment(name, file, content_type: 'binary/octet-stream')
          result = _couchrest_database.put_attachment(
            to_hash, name, file, content_type: content_type
          )
          self._rev = result['rev'] if result['ok']
          result
        end

        def fetch_couch_attachment(name)
          _couchrest_database.fetch_attachment(to_hash, name)
        rescue RestClient::ResourceNotFound
          nil
        end

        def delete_couch_attachment(name)
          result = _couchrest_database.delete_attachment(to_hash, name)
          self._rev = result['rev'] if result['ok']
          result
        end

        def couch_attachment_names
          (_attachments || {}).keys
        end

        def couch_attachment?(name)
          couch_attachment_names.include?(name.to_s)
        end

        # ── High-level: has_couch_attached ──────────────────────────────

        def self.define_couch_attached(base, name, options = {})
          options = {
            content_type: nil,
            filename: nil   # template: '{updated_at|iso8601date}-invoice.pdf'
          }.merge(options)

          # Properties for metadata
          base.property :"#{name}_content_type"
          base.property :"#{name}_size"

          # Resolve the attachment filename
          base.define_method(:"#{name}_filename") do
            template = options[:filename] || name.to_s
            if template.include?('{')
              _resolve_filename_template(template)
            else
              template
            end
          end

          # Getter — fetches from CouchDB on first access
          base.define_method(name) do
            cache_key = :"@_couch_attachment_#{name}"
            return instance_variable_get(cache_key) if instance_variable_defined?(cache_key)

            filename = public_send(:"#{name}_filename")
            data = fetch_couch_attachment(filename)
            instance_variable_set(cache_key, data)
            data
          end

          # Setter — queues attachment for save
          base.define_method(:"#{name}=") do |value|
            cache_key = :"@_couch_attachment_#{name}"
            instance_variable_set(cache_key, value)

            # Detect content type
            content_type = options[:content_type] || _detect_content_type(value)
            public_send(:"#{name}_content_type=", content_type) if value

            # Track size
            size = value.respond_to?(:bytesize) ? value.bytesize : value.to_s.bytesize
            public_send(:"#{name}_size=", size) if value

            # Queue for save
            @_pending_couch_attachments ||= {}
            @_pending_couch_attachments[name] = {
              filename: public_send(:"#{name}_filename"),
              file: value,
              content_type: content_type
            }
            value
          end

          # URL getter
          base.define_method(:"#{name}_url") do
            db_url = database.couchrest_database_url
            doc_id = _id
            filename = public_send(:"#{name}_filename")
            "#{db_url}/#{doc_id}/#{filename}"
          end
        end

        private

        def _save_pending_couch_attachments
          return unless @_pending_couch_attachments&.any?

          @_pending_couch_attachments.each do |_name, opts|
            put_couch_attachment(opts[:filename], opts[:file], content_type: opts[:content_type])
          end
          @_pending_couch_attachments = nil
        end

        def _detect_content_type(data)
          return nil unless data.is_a?(String) || data.respond_to?(:read)
          # Try to detect from magic bytes using the `marcel` gem if available,
          # otherwise fall back to octet-stream.
          if defined?(Marcel)
            content = data.respond_to?(:read) ? data.read : data
            Marcel::MimeType.for(StringIO.new(content.to_s))
          else
            'binary/octet-stream'
          end
        rescue StandardError
          'binary/octet-stream'
        end

        def _resolve_filename_template(template)
          template.gsub(/\{(\w+)(?:\|(\w+))?\}/) do
            method = Regexp.last_match(1)
            format = Regexp.last_match(2)
            value = respond_to?(method) ? send(method) : nil
            if format && value.respond_to?(:"to_#{format}")
              value.send(:"to_#{format}")
            else
              value.to_s
            end
          end
        end

        def _couchrest_database
          if respond_to?(:database) && database.respond_to?(:couchrest_database)
            database.couchrest_database
          else
            self.class.database.couchrest_database
          end
        end
      end
    end
  end
end
