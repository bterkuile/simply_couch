# frozen_string_literal: true

# CouchDB inline attachment support.
# Adds put_attachment, fetch_attachment, delete_attachment, and attachment_names
# to any SimplyCouch model.
#
# Usage:
#   class Invoice
#     include SimplyCouch::Model
#     include SimplyCouch::Model::Attachments
#   end
#
#   invoice.put_attachment('invoice.pdf', file, content_type: 'application/pdf')
#   invoice.fetch_attachment('invoice.pdf') # => file data
#   invoice.delete_attachment('invoice.pdf')
#   invoice.attachment_names # => ['invoice.pdf', 'logo.png']
#
module SimplyCouch
  module Model
    module Attachments
      def self.included(base)
        base.after_save :_save_pending_attachments
      end

      # Upload a file as a CouchDB inline attachment on this document.
      # The attachment is stored immediately — no need to call save separately.
      # Returns the CouchDB result hash.
      def put_attachment(name, file, content_type: 'binary/octet-stream')
        result = _couchrest_database.put_attachment(
          to_hash, name, file, content_type: content_type
        )
        self._rev = result['rev'] if result['ok']
        result
      end

      # Fetch an attachment's binary data from CouchDB.
      # Returns nil if the attachment doesn't exist.
      def fetch_attachment(name)
        _couchrest_database.fetch_attachment(to_hash, name)
      rescue RestClient::ResourceNotFound
        nil
      end

      # Queue an attachment for upload on next save.
      # Useful when building a new document that hasn't been saved yet
      # (no _rev available for immediate put_attachment).
      def add_attachment(name, file, content_type: 'binary/octet-stream')
        @_pending_attachments ||= {}
        @_pending_attachments[name] = { file: file, content_type: content_type }
      end

      # Delete an attachment from this document.
      # The attachment is removed immediately — no need to call save separately.
      def delete_attachment(name)
        result = _couchrest_database.delete_attachment(to_hash, name)
        self._rev = result['rev'] if result['ok']
        result
      end

      # List all attachment names on this document.
      def attachment_names
        (_attachments || {}).keys
      end

      # Check if an attachment exists.
      def attachment?(name)
        attachment_names.include?(name.to_s)
      end

      private

      def _save_pending_attachments
        return unless @_pending_attachments&.any?

        @_pending_attachments.each do |name, opts|
          put_attachment(name, opts[:file], content_type: opts[:content_type])
        end
        @_pending_attachments = nil
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
