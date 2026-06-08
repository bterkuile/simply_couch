# frozen_string_literal: true

module SimplyCouch
  module Model
    module Attachment
      # Drop-in replacement for Paperclip in SimplyCouch/CouchDB models.
      #
      # Usage:
      #   class Image
      #     include SimplyCouch::Model
      #     has_local_attached :file, styles: {
      #       medium: "354x1000>",
      #       thumb:  "160x1250>"
      #     }
      #   end
      #
      # Auto-declares CouchDB properties:
      #   <name>_file_name, <name>_content_type, <name>_file_size, <name>_updated_at
      #
      # Files stored at: public/system/<attachment>/<id>/original.<ext>
      # Uses MiniMagick (ImageMagick) for thumbnail generation.
      module Local
        # Proxy object returned by attachment getters (e.g. `image.file`).
        # Mimics the Paperclip::Attachment API that views expect.
        class Proxy
          def initialize(record, name)
            @record = record
            @name = name
          end

          def present?
            @record.send(:"#{@name}_file_name").present?
          end

          def blank?
            !present?
          end

          alias file? present?
          alias exists? present?

          def url(style = nil)
            @record.send(:"#{@name}_url", style)
          end

          def original_filename
            @record.send(:"#{@name}_file_name")
          end

          def content_type
            @record.send(:"#{@name}_content_type")
          end

          def size
            @record.send(:"#{@name}_file_size")
          end

          def method_missing(method, *args, &block)
            if @record.respond_to?(method, true)
              @record.send(method, *args, &block)
            else
              super
            end
          end

          def respond_to_missing?(method, include_private = false)
            @record.respond_to?(method, include_private) || super
          end
        end

        def self.define_local_attached(base, name, styles: {}, default_url: nil, default_style: :original, content_type: nil)
          # Auto-declare CouchDB properties for attachment metadata
          base.property :"#{name}_file_name"
          base.property :"#{name}_content_type"
          base.property :"#{name}_file_size", type: Integer
          base.property :"#{name}_updated_at", type: Time

          # Auto-validate content type (replaces Paperclip validates_attachment_content_type)
          if content_type
            base.validate :"#{name}_content_type_must_be_allowed"
            base.define_method(:"#{name}_content_type_must_be_allowed") do
              fname = send(:"#{name}_file_name")
              return if fname.blank?
              ctype = send(:"#{name}_content_type")
              allowed = content_type.is_a?(Array) ? content_type : [content_type]
              unless allowed.any? { |t| ctype&.start_with?(t) || ctype == t }
                errors.add(name, "must be one of: #{allowed.join(', ')}")
              end
            end
          end

          # Register configuration
          base.attachment_registry[name] = {
            styles: styles,
            default_url: default_url,
            default_style: default_style
          }

          # ---- Setter: model.file = uploaded_file ----
          base.define_method(:"#{name}=") do |uploaded|
            if uploaded.nil? || (uploaded.respond_to?(:empty?) && uploaded.empty?)
              send(:"#{name}_file_name=", nil)
              send(:"#{name}_content_type=", nil)
              send(:"#{name}_file_size=", nil)
              send(:"#{name}_updated_at=", nil)
              return
            end

            config = self.class.attachment_registry[name]

            original_filename = if uploaded.respond_to?(:original_filename)
                                  uploaded.original_filename
                                elsif uploaded.respond_to?(:path)
                                  File.basename(uploaded.path)
                                else
                                  'file'
                                end
            ext = File.extname(original_filename)
            ext = '.bin' if ext.blank?

            content_type = uploaded.respond_to?(:content_type) ? uploaded.content_type : nil
            file_size    = uploaded.respond_to?(:size) ? uploaded.size : nil

            content = if uploaded.respond_to?(:read)
                        data = uploaded.read
                        uploaded.rewind if uploaded.respond_to?(:rewind)
                        data
                      elsif uploaded.respond_to?(:path) && File.exist?(uploaded.path)
                        File.binread(uploaded.path)
                      elsif uploaded.respond_to?(:tempfile)
                        uploaded.tempfile.read
                      else
                        uploaded.to_s
                      end

            record_id = respond_to?(:id) && id.present? ? id.to_s : 'tmp'
            base_dir = Rails.root.join('public', 'system', name.to_s, record_id)
            FileUtils.mkdir_p(base_dir)

            begin
              original_path = base_dir.join("original#{ext}")
              File.binwrite(original_path, content)

              config[:styles].each do |style_name, geometry|
                style_path = base_dir.join("#{style_name}#{ext}")
                begin
                  image = MiniMagick::Image.open(original_path.to_s)
                  image.resize(geometry)
                  image.write(style_path.to_s)
                rescue StandardError => e
                  Rails.logger.warn("[HasAttachment] Could not generate #{style_name} for #{name}: #{e.message}")
                  FileUtils.cp(original_path, style_path)
                end
              end

              send(:"#{name}_file_name=", original_filename)
              send(:"#{name}_content_type=", content_type)
              send(:"#{name}_file_size=", file_size || content.bytesize)
              send(:"#{name}_updated_at=", Time.current)
            rescue StandardError => e
              errors.add(name, "could not be processed: #{e.message}")
              Rails.logger.error("[HasAttachment] Error processing #{name}: #{e.message}")
            end
          end

          # ---- Getter: model.file → Proxy ----
          base.define_method(name) do
            Proxy.new(self, name)
          end

          # ---- Presence check: model.file? ----
          base.define_method(:"#{name}?") do
            send(:"#{name}_file_name").present?
          end

          # ---- URL helper: model.file_url(:thumb) ----
          base.define_method(:"#{name}_url") do |style_name = nil|
            config = self.class.attachment_registry[name]
            style_name ||= config[:default_style]

            fname = send(:"#{name}_file_name")
            if fname.blank?
              return config[:default_url] if config[:default_url]
              return nil
            end

            ext = File.extname(fname)
            record_id = respond_to?(:id) && id.present? ? id.to_s : 'tmp'
            "/system/#{name}/#{record_id}/#{style_name}#{ext}"
          end

          # ---- Backward compat: *_path for Paperclip migrations ----
          base.define_method(:"#{name}_path") do |style_name = nil|
            config = self.class.attachment_registry[name]
            style_name ||= config[:default_style]

            fname = send(:"#{name}_file_name")
            return nil if fname.blank?

            ext = File.extname(fname)
            record_id = respond_to?(:id) && id.present? ? id.to_s : 'tmp'
            Rails.root.join('public', 'system', name.to_s, record_id, "#{style_name}#{ext}").to_s
          end
        end

        # Backward compat: old code calls has_attachment directly.
        # Delegate to define_local_attached.
        def self.included(base)
          base.extend(ClassMethods)
        end

        module ClassMethods
          def has_attachment(name, styles: {}, default_url: nil, default_style: :original)
            Local.define_local_attached(self, name, styles: styles, default_url: default_url, default_style: default_style)
          end

          def attachment_registry
            @_has_attachment_registry ||= {}
          end
        end
      end
    end
  end
end
