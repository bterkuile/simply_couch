# frozen_string_literal: true

# Backward compatibility shim — delegates to SimplyCouch::Model::Attachment::Local.
# Prefer `has_local_attached :name` directly on your SimplyCouch::Model class.
#
# Old usage (still works):
#   class Image
#     include SimplyCouch::Model
#     include SimplyCouch::HasAttachment
#     has_attachment :file, styles: { thumb: "100x100>" }
#   end
#
# New usage (preferred):
#   class Image
#     include SimplyCouch::Model
#     has_local_attached :file, styles: { thumb: "100x100>" }
#   end

require 'simply_couch/model/attachment/local'

module SimplyCouch
  module HasAttachment
    def self.included(base)
      base.include SimplyCouch::Model::Attachment::Local
      base.extend SimplyCouch::Model::Attachment::Local::ClassMethods
    end
  end
end
