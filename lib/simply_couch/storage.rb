# frozen_string_literal: true

# Backward compatibility shim — delegates to SimplyCouch::Model::Attachment::S3.
# Prefer `has_s3_attached :name` directly on your SimplyCouch::Model class.

require 'simply_couch/model/attachment/s3'

module SimplyCouch
  module Storage
    module ClassMethods
      def has_s3_attached(name, options = {})
        SimplyCouch::Model::Attachment::S3.define_s3_attached(self, name, options)
        include SimplyCouch::Model::Attachment::S3::InstanceMethods
      end
      alias_method :has_s3_attachment, :has_s3_attached
    end
  end
end
