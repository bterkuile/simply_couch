# frozen_string_literal: true

module SimplyCouch
  module Model
    module Attachment
      # S3 attachment strategy — uses aws-sdk-s3.
      #
      # Lazy-loaded via has_s3_attached / has_s3_attachment macro on SimplyCouch::Model.
      #
      # Config (per environment):
      #   SimplyCouch.s3_defaults = { bucket: 'myapp', access_key: '...', ... }
      #   SimplyCouch.load_s3_config(Rails.root.join('config', 's3.yml'))
      #
      # Usage:
      #   class Report
      #     include SimplyCouch::Model
      #     has_s3_attached :pdf
      #   end
      #
      #   report.pdf = File.read('monthly.pdf')
      #   report.save
      #   report.pdf_url  # presigned S3 URL
      #
      module S3
        module InstanceMethods
          def _s3_options
            self.class._s3_options
          end

          def s3_client
            @_s3_client ||= begin
              creds = _s3_options.values.first
              Aws::S3::Client.new(
                access_key_id: creds[:access_key],
                secret_access_key: creds[:secret_access_key],
                region: _s3_region(creds),
                logger: creds[:logger]
              )
            end
          end

          def s3_bucket(name)
            return @_s3_bucket if @_s3_bucket
            opts = _s3_options[name]
            begin
              s3_client.head_bucket(bucket: opts[:bucket])
            rescue Aws::S3::Errors::NotFound, Aws::S3::Errors::NoSuchBucket
              s3_client.create_bucket(
                bucket: opts[:bucket],
                create_bucket_configuration: _s3_region(opts) == 'us-east-1' ? nil : { location_constraint: _s3_region(opts) }
              )
            rescue Aws::S3::Errors::Forbidden, Aws::S3::Errors::BucketAlreadyOwnedByYou
              # bucket exists but we can't check — proceed
            end
            @_s3_bucket = opts[:bucket]
          rescue StandardError => e
            raise ArgumentError, "Could not access/create S3 bucket '#{name}': #{e}"
          end

          def save(validate = true)
            update_attachment_sizes
            if ret = super(validate)
              save_attachments
            end
            ret
          end

          def save!(*args)
            update_attachment_sizes
            super
            save_attachments
          end

          def delete(*args)
            delete_attachments
            super
          end

          def destroy(*args)
            delete_attachments
            super
          end

          def save_attachments
            return unless id.present?
            if @_s3_attachments
              @_s3_attachments.each do |name, attachment|
                if attachment[:dirty]
                  value = attachment[:value].is_a?(String) ? attachment[:value] : attachment[:value].to_json
                  s3_bucket(name)
                  s3_client.put_object(
                    bucket: _s3_options[name][:bucket],
                    key: s3_attachment_key(name),
                    body: value,
                    acl: _s3_options[name][:permissions]
                  )
                  attachment[:dirty] = false
                end
              end
            end
          end

          def delete_attachments
            return unless id.present?
            (@_s3_attachments || {}).each do |name, attachment|
              if _s3_options[name][:after_delete] == :delete
                s3_client.delete_object(
                  bucket: _s3_options[name][:bucket],
                  key: s3_attachment_key(name)
                )
              end
            end
          end

          def update_attachment_sizes
            if @_s3_attachments
              @_s3_attachments.each do |name, attachment|
                if attachment[:dirty]
                  value = attachment[:value].is_a?(String) ? attachment[:value] : attachment[:value].to_json
                  public_send("#{name}_size=", (value.size rescue nil))
                end
              end
            end
          end

          def s3_attachment_key(name)
            "#{self.class.name.tableize}/#{name}/#{id}"
          end

          private

          def _s3_region(opts)
            case opts[:location]
            when :eu then 'eu-west-1'
            when :us, nil then 'us-east-1'
            else opts[:location].to_s
            end
          end
        end

        def self.define_s3_attached(base, name, options = {})
          require 'aws-sdk-s3'

          name = name.to_sym
          base.singleton_class.class_eval { attr_accessor :_s3_options }

          # Merge: model options > global s3_defaults > gem defaults
          base.property :"#{name}_size" if base.respond_to?(:property)

        defaults = (SimplyCouch.s3_defaults || {}).merge(options)
          raise ArgumentError, "No bucket name specified for attachment #{name}" if defaults[:bucket].blank?
          defaults = {
            permissions: 'private',
            ssl: true,
            location: :us,
            ca_file: nil,
            after_delete: :nothing,
            logger: nil
          }.update(defaults)
          base._s3_options ||= {}
          base._s3_options[name] = defaults

          _define_s3_accessors(base, name)
          base.attr_reader :_s3_attachments
          base.include InstanceMethods
        end

        def self._define_s3_accessors(base, name)
          base.define_method(name) do
            unless @_s3_attachments && @_s3_attachments[name]
              @_s3_attachments = { name => {} }
              resp = s3_client.get_object(
                bucket: _s3_options[name][:bucket],
                key: s3_attachment_key(name)
              )
              @_s3_attachments[name][:value] = resp.body.read
            end
            @_s3_attachments[name][:value]
          end

          base.define_method("#{name}=") do |value|
            @_s3_attachments ||= {}
            @_s3_attachments[name] ||= {}
            @_s3_attachments[name].update(value: value, dirty: true)
            value
          end

          base.define_method("#{name}_url") do
            opts = _s3_options[name]
            signer = Aws::S3::Presigner.new(client: s3_client)
            signer.presigned_url(
              :get_object,
              bucket: opts[:bucket],
              key: s3_attachment_key(name),
              expires_in: opts[:permissions] == 'private' ? 300 : 3600
            )
          end
        end
      end
    end
  end
end
