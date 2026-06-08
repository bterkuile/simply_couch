# frozen_string_literal: true

# Backward compatibility shim — delegates to SimplyCouch::Model::Attachment::Local.
# Prefer `has_local_attached :name` directly on your SimplyCouch::Model class.

require 'simply_couch/model/attachment/local'

module SimplyCouch
  module HasAttachment
    def self.included(base)
      base.include SimplyCouch::Model::Attachment::Local
      base.extend SimplyCouch::Model::Attachment::Local::ClassMethods
    end
  end
end
