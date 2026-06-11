# frozen_string_literal: true

# Persistence — replaces CouchPotato::Persistence.
# Provides property macro, callbacks, JSON, dirty tracking, timestamps, validations.
#
module SimplyCouch
  module Model
    module Persistence
      require 'active_support/time'

      def self.included(base)
        base.instance_variable_set(:@properties, nil) if base.instance_variable_defined?(:@properties)
        base.send :include, Properties
        base.send :include, Callbacks
        base.send :include, Json
        base.send :include, DirtyAttributes
        base.send :include, MagicTimestamps
        base.send :include, ActiveModelCompliance
        base.send :include, ForbiddenAttributesProtection
        base.send :include, Revisions
        base.send :include, Validation
        base.send :include, View::CustomViews
        base.send :include, View::Lists

        base.class_eval do
          attr_accessor :_id, :_rev, :_deleted, :_attachments, :database, :_document
          alias_method :id, :_id
          alias_method :id=, :_id=

          def _document=(val)
            @_document = val.is_a?(Hash) ? ActiveSupport::HashWithIndifferentAccess.new(val) : val
          end
        end
      end

      # ── initialize / attributes ────────────────────────────────────────

      def initialize(attributes = {})
        if attributes
          @skip_dirty_tracking = true
          begin
            self.attributes = attributes
          ensure
            # Always restore tracking, even if a setter raises, so the instance
            # isn't left permanently ignoring dirty state.
            @skip_dirty_tracking = false
          end
        end
        yield self if block_given?
      end

      def attributes=(hash)
        hash.each { |attribute, value| self.public_send "#{attribute}=", value }
      end

      def attributes
        self.class.properties.inject(ActiveSupport::HashWithIndifferentAccess.new) do |res, property|
          property.value(res, self)
          res
        end
      end

      def []=(attribute, value); public_send("#{attribute}=", value); end
      def [](attribute); public_send(attribute); end
      def has_key?(key); attributes.has_key?(key); end
      def new?; _rev.nil?; end
      alias_method :new_record?, :new?
      def to_param; _id; end

      def ==(other)
        super || (self.class == other.class && self._id.present? && self._id == other._id)
      end
      def eql?(other); self == other; end
      def hash; _id.hash * (_id.hash.to_s.size ** 10) + _rev.hash; end
      def inspect
        attrs = attributes.map {|k,v| "#{k}: #{v.inspect}"}.join(", ")
        %Q{#<#{self.class} _id: "#{_id}", _rev: "#{_rev}", #{attrs}>}
      end

      # ── Properties ─────────────────────────────────────────────────────

      module Properties
        class PropertyList
          include Enumerable
          attr_accessor :list

          def initialize(clazz)
            @clazz = clazz
            @list = []
            @hash = {}
          end

          def each(&block); (list + inherited_properties).each(&block); end
          def <<(property); @hash[property.name] = property; @list << property; end
          def find_property(name); @hash[name] || @clazz.superclass.properties.find_property(name); end
          def inspect; list.map(&:name).inspect; end

          def inherited_properties
            superclazz = @clazz.superclass
            properties = []
            while superclazz && superclazz.respond_to?(:properties)
              properties << superclazz.properties.list
              superclazz = superclazz.superclass
            end
            properties.flatten
          end
        end

        def self.included(base)
          base.extend ClassMethods
          base.class_eval do
            def self.properties
              @properties ||= {}
              @properties[name] ||= PropertyList.new(self)
              @properties[name]
            end
          end
        end

        def type_caster; @type_caster ||= TypeCaster.new; end

        module ClassMethods
          def property_names; properties.map(&:name); end

          def property(name, options = {})
            am = send(:generated_attribute_methods)
            am.module_eval { undef_method(name) if instance_methods.include?(name) }
            define_attribute_method name
            properties << SimpleProperty.new(self, name, options)
            am.send(:remove_method, name) if am.instance_methods.include?(name)
          end

          def check_existing_properties(name, type)
            existing = properties.find{|p| name.to_sym == p.name.to_sym}
            return if existing.nil? || existing.class == type
            raise "Property #{name} already defined as #{existing.class}, cannot redefine as #{type}"
          end
        end
      end

      # ── SimpleProperty ──────────────────────────────────────────────────

      module PropertyMethods
        private
        def load_attribute_from_document(name)
          if _document&.has_key?(name)
            property = self.class.properties.find_property(name)
            @skip_dirty_tracking = true
            value = property.build(self, _document)
            @skip_dirty_tracking = false
            value
          end
        end
      end

      class SimpleProperty
        attr_accessor :name, :type

        def initialize(owner_clazz, name, options = {})
          self.name = name
          @setter_name = "#{name}="
          self.type = options[:type]
          @type_caster = TypeCaster.new
          owner_clazz.send(:include, PropertyMethods) unless owner_clazz.ancestors.include?(PropertyMethods)
          define_accessors(accessors_module_for(owner_clazz), name, options)
        end

        def build(object, json); object.public_send @setter_name, json[name]; end
        def changed?(object); object.public_send("#{name}_changed?"); end
        def serialize(json, object); json[name] = @type_caster.cast_back object.public_send(name); end
        alias :value :serialize

        private

        def module_for(clazz, name)
          suffix = "#{clazz.name.to_s.gsub('::', '__')}#{name}"
          unless clazz.const_defined?(suffix)
            clazz.const_set(suffix, Module.new).tap {|m| clazz.send(:include, m) }
          end
          clazz.const_get(suffix)
        end

        def accessors_module_for(clazz); module_for(clazz, "AccessorMethods"); end

        def define_accessors(base, name, options)
          ivar = "@#{name}".freeze
          base.class_eval do
            define_method(name) do
              load_attribute_from_document(name) unless instance_variable_defined?(ivar)
              value = instance_variable_get(ivar)
              if value.nil? && !options[:default].nil?
                default = if options[:default].respond_to?(:call)
                  options[:default].arity == 1 ? options[:default].call(self) : options[:default].call
                else
                  clone_attribute(options[:default])
                end
                instance_variable_set(ivar, default)
              else
                value
              end
            end

            define_method("#{name}=") do |value|
              typecasted = type_caster.cast(value, options[:type])
              public_send("#{name}_will_change!") unless @skip_dirty_tracking || typecasted == public_send(name)
              instance_variable_set(ivar, typecasted)
            end

            define_method("#{name}?") { !send(name).nil? && !send(name).try(:blank?) }
          end
        end
      end

      # ── Callbacks ────────────────────────────────────────────────────────

      module Callbacks
        extend ActiveSupport::Concern
        include ActiveSupport::Callbacks

        included do
          define_callbacks :validate, :validation,
                          :validation_on_save, :validation_on_create, :validation_on_update,
                          :save, :create, :update, :destroy
          %w(validate validation save create update destroy).each do |cb|
            class_eval <<-RUBY, __FILE__, __LINE__
              def self.before_#{cb}(*args, &block); set_callback :#{cb}, :before, *args, &block; end
              def self.after_#{cb}(*args, &block);  set_callback :#{cb}, :after, *args, &block; end
              def self.around_#{cb}(*args, &block); set_callback :#{cb}, :around, *args, &block; end
            RUBY
          end
          %w(validation_on_create validation_on_update).each do |cb|
            class_eval <<-RUBY, __FILE__, __LINE__
              def self.before_#{cb}(*args, &block); set_callback :#{cb}, :before, *args, &block; end
              def self.after_#{cb}(*args, &block);  set_callback :#{cb}, :after, *args, &block; end
            RUBY
          end
        end
      end

      # ── Dirty Attributes ─────────────────────────────────────────────────

      module DirtyAttributes
        def self.included(base)
          base.send :include, ActiveModel::Dirty
          base.send :alias_method, :dirty?, :changed?
        
          base.class_eval { after_save :clear_changes_information }
        end
        private
        # Deep-copy a (default) attribute value so instances never share mutable
        # state. Recurses through Hash/Array instead of Marshal.dump/load, which
        # is both lighter and avoids the Marshal round-trip (Marshal can't dump
        # some objects and is flagged by security scanners). Preserves the hash
        # subclass (e.g. HashWithIndifferentAccess).
        def clone_attribute(value)
          case value
          when Integer, Symbol, TrueClass, FalseClass, NilClass, Float
            value
          when Array
            value.map { |element| clone_attribute(element) }
          when Hash
            value.each_with_object(value.class.new) do |(k, v), copy|
              copy[clone_attribute(k)] = clone_attribute(v)
            end
          else
            value.clone
          end
        end
      end

      # ── JSON ─────────────────────────────────────────────────────────────

      module Json
        def to_json(*args); to_hash(*args).to_json(*args); end
        def to_hash(options = nil)
          doc = { 'ruby_class' => self.class.name, '_id' => _id, '_rev' => _rev }.reject { |_, v| v.nil? }.merge(@_document || {})
          (self.class.properties || []).inject(doc) {|d, p| p.serialize(d, self); d }
        end
        alias :as_json :to_hash
        def _document; @_document ||= {}; end
        def _document=(val)
          @_document = val.is_a?(Hash) ? ActiveSupport::HashWithIndifferentAccess.new(val) : val
        end

        def self.included(base)
          base.extend ClassMethods
        end

        module ClassMethods
          # Called by JSON.parse to hydrate documents into model instances.
          # Looks for 'ruby_class' key (mozo convention) or 'json_class' (standard).
          def json_create(json)
            return if json.nil?
            doc = ActiveSupport::HashWithIndifferentAccess.new(json)
            instance = new
            instance.instance_variable_set(:@_document, doc)
            instance._id = doc[:_id] || doc['_id']
            instance._rev = doc[:_rev] || doc['_rev']
            instance._attachments = doc[:_attachments] || doc['_attachments']
            instance
          end
        end
      end

      # ── Magic Timestamps ─────────────────────────────────────────────────

      module MagicTimestamps
        def self.included(base)
          base.instance_eval do
            property :created_at, type: Time
            property :updated_at, type: Time
            before_create :set_created_at
            before_save :set_updated_at
          end
        end
        private
        def set_created_at; self.created_at ||= Time.now; end
        def set_updated_at; self.updated_at = Time.now; end
      end

      # ── ActiveModel Compliance ───────────────────────────────────────────

      module ActiveModelCompliance
        extend ActiveSupport::Concern
        def persisted?; !new? && !destroyed?; end
        def destroyed?; @destroyed || false; end
        def to_key; persisted? ? [id] : nil; end
        def to_model; self; end
      end

      # ── Forbidden Attributes Protection ──────────────────────────────────

      module ForbiddenAttributesProtection
        # Rails 5+ uses strong parameters at controller level — stub only
      end

      # ── Revisions ────────────────────────────────────────────────────────

      module Revisions
        def self.included(base)
          base.class_eval do
            def self.revisions(ids)
              return [] if ids.empty?
              database.couchrest_database.bulk_load(ids)
            end
          end
        end
      end

      # ── Validation ───────────────────────────────────────────────────────

      module Validation
        extend ActiveSupport::Concern
        include ActiveModel::Validations
      end

      # ── Type Caster ──────────────────────────────────────────────────────

      class TypeCaster
        # Cast a value to the given type.
        # Supports:
        #   type: SomeClass           — direct class reference
        #   type: :boolean, :integer  — symbol (lazy, Rails autoloading safe)
        #   type: 'ClassName'         — string (constantize in Rails)
        def cast(value, type = nil)
          return value unless type
          resolved = resolve_type(type)
          # If resolved is a Module (class), try to coerce
          if resolved.is_a?(Module)
            return value if value.is_a?(resolved)
            return cast_to_builtin(value, resolved)
          end
          value
        end

        private

        def cast_to_builtin(value, klass)
          case klass.name
          when 'Integer'  then value.to_i
          when 'Float'    then value.to_f
          when 'String'   then value.to_s
          when 'Symbol'   then value.to_sym
          when 'TrueClass', 'FalseClass' then !!value
          when 'Array'    then value.is_a?(Array) ? value : [value]
          when 'Hash'     then value.is_a?(Hash) ? value : { value: value }
          when 'Time', 'DateTime', 'Date'
            value.is_a?(String) ? Time.parse(value) : value
          else value
          end
        end

        public
        def cast_back(value)
          value.respond_to?(:iso8601) ? value.iso8601 : value
        end

        private

        # Map symbols and strings to Ruby classes.
        # Symbols are preferred — they work without Rails autoloading.
        BUILTIN_TYPES = {
          boolean:    [TrueClass, FalseClass],
          integer:    Integer,
          float:      Float,
          string:     String,
          symbol:     Symbol,
          time:       Time,
          datetime:   DateTime,
          date:       Date,
            array:      Array,
          hash:       Hash,
        }.freeze

        def resolve_type(type)
          case type
          when Symbol
            mapped = BUILTIN_TYPES[type]
            mapped || (Object.const_get(type.to_s.classify) rescue type)
          when String
            Object.const_get(type) rescue type
          when Module
            type
          else
            type
          end
        end
      end
    end
  end
end
