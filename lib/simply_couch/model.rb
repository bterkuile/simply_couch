require 'active_model'

CouchRest.decode_json_objects = true
require 'json'
JSON.create_id = 'ruby_class'

require 'active_support'
unless {}.respond_to?(:assert_valid_keys)
  require 'active_support/core_ext'
end
I18n.load_path << File.join(File.expand_path(File.dirname(__FILE__)), 'locale', 'en.yml')
require File.expand_path(File.dirname(__FILE__) + '/../simply_couch')
require 'simply_couch/model/database'
require 'simply_couch/model/validations'
require 'simply_couch/model/pagination_options'
require 'simply_couch/model/association_property'
require 'simply_couch/model/properties'
require 'simply_couch/model/ancestry'
require 'simply_couch/model/finders'
require 'simply_couch/model/find_by'
require 'simply_couch/model/belongs_to'
require 'simply_couch/model/embedded_in'
require 'simply_couch/model/has_many'
require 'simply_couch/model/has_many_embedded'
require 'simply_couch/model/has_and_belongs_to_many'
require 'simply_couch/model/has_one'
require 'simply_couch/model/attachments'
require 'simply_couch/model/pagination'
require 'simply_couch/model/persistence'
require 'simply_couch/model/view'
require 'simply_couch/model/views'
require 'simply_couch/include_relation'

module SimplyCouch
  module Model
    def self.included(clazz)
      clazz.send(:include, Persistence)
      clazz.send(:include, InstanceMethods)
      clazz.send(:extend, ClassMethods)

      clazz.instance_eval do
        attr_accessor :_accessible_attributes, :_protected_attributes

        view :all_documents, :key => :created_at
      end
    end

    module ClassMethods
      include SimplyCouch::ClassMethods::Base
      include SimplyCouch::Model::Database
      include SimplyCouch::Model::Validations
      include SimplyCouch::Model::BelongsTo
      include SimplyCouch::Model::EmbeddedIn
      include SimplyCouch::Model::HasMany
      include SimplyCouch::Model::HasManyEmbedded
      include SimplyCouch::Model::HasAndBelongsToMany
      include SimplyCouch::Model::HasOne
      include SimplyCouch::Model::Finders
      include SimplyCouch::Model::FindBy
      include SimplyCouch::Model::Pagination
      include SimplyCouch::Model::PaginationOptions
      include SimplyCouch::Storage::ClassMethods
      include SimplyCouch::Model::Ancestry

      def create(attributes = {}, &blk)
        instance = new(attributes, &blk)
        instance.save
        instance
      end

      def create!(attributes = {}, &blk)
        instance = new(attributes, &blk)
        instance.save!
        instance
      end

      def enable_soft_delete(property_name = :deleted_at)
        @_soft_delete_attribute = property_name.to_sym
        property property_name, :type => Time
        _define_hard_delete_methods
        _define_soft_delete_views
      end

      def soft_delete_attribute
        @_soft_delete_attribute
      end

      def soft_deleting_enabled?
        !soft_delete_attribute.nil?
      end

      def split_design_documents_per_view(enabled = true)
        @_split_design_documents = enabled
      end

      def split_design_documents?
        @_split_design_documents || false
      end

      def auto_conflict_resolution_on_save
        @auto_conflict_resolution_on_save.nil? ? true : @auto_conflict_resolution_on_save
      end

      def auto_conflict_resolution_on_save=(val)
        @auto_conflict_resolution_on_save = val
      end

      def method_missing(name, *args)
        if name.to_s =~ /^find_by/
          _define_find_by(name, *args)
        elsif name.to_s =~ /^find_all_by/
          _define_find_all_by(name, *args)
        elsif name.to_s =~ /^count_by/
          _define_count_by(name, *args)
        else
          super
        end
      end

      def _define_hard_delete_methods
        define_method("destroy!") do
          destroy(true)
        end

        define_method("delete!") do
          destroy(true)
        end
      end

      def _define_soft_delete_views
        view :all_documents_without_deleted, :type => SimplyCouch::Model::Views::DeletedModelViewSpec
      end

      def _define_cache_accessors(name, options)
        define_method "_get_cached_#{name}" do
          instance_variable_get("@#{name}") || {}
        end

        define_method "_set_cached_#{name}" do |value, cache_key|
          cached = send("_get_cached_#{name}")
          cached[cache_key] = value
          instance_variable_set("@#{name}", cached)
        end

        define_method "_cache_key_for" do |opt|
          opt.blank? ? :all : opt.to_s
        end
      end
    end

    def extract_association_options(local_options = nil)
      forced_reload = false
      with_deleted = false
      limit = nil
      descending = false
      skip = nil

      if local_options
        local_options.assert_valid_keys(:force_reload, :with_deleted, :limit, :order)
        forced_reload = local_options.delete(:force_reload)
        with_deleted = local_options[:with_deleted]
        limit = local_options[:limit]
        descending = (local_options[:order] == :desc) ? true : false
        skip = local_options[:skip]
      end
      return [forced_reload, with_deleted, limit, descending, skip]
    end

    def self.delete_all_design_documents(database)
      db = CouchRest.database(database)
      db.info # ensure DB exists
      design_docs = CouchRest.get("#{database}/_all_docs?startkey=%22_design%22&endkey=%22_design0%22")['rows'].map do |row|
        [row['id'], row['value']['rev']]
      end
      design_docs.each do |doc_id, rev|
        db.delete_doc({'_id' => doc_id, '_rev' => rev})
      end
      design_docs.size
    end

    def self.compact_all_design_documents(database)
      db = CouchRest.database(database)
      db.info # ensure DB exists
      design_docs = CouchRest.get("#{database}/_all_docs?startkey=%22_design%22&endkey=%22_design0%22")['rows'].map do |row|
        [row['id'], row['value']['rev']]
      end
      design_docs.each do |doc_id, rev|
        puts "#{database}/_compact/#{doc_id.gsub("_design/",'')}"
        CouchRest.post("#{database}/_compact/#{doc_id.gsub("_design/",'')}")
      end
      design_docs.size
    end

  end
end
