module SimplyCouch
  module Storage
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
              s3_bucket(name)  # ensure bucket exists
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
              send("#{name}_size=", (value.size rescue nil))
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

    module ClassMethods
      def has_s3_attachment(name, options = {})
        require 'aws-sdk-s3'

        name = name.to_sym

        self.class.instance_eval do
          attr_accessor :_s3_options
        end

        self.class_eval do
          if respond_to?(:property)
            property "#{name}_size"
          else
            simpledb_integer "#{name}_size"
          end
        end

        raise ArgumentError, "No bucket name specified for attachment #{name}" if options[:bucket].blank?
        options = {
          permissions: 'private',
          ssl: true,
          location: :us,
          ca_file: nil,
          after_delete: :nothing,
          logger: nil
        }.update(options)
        self._s3_options ||= {}
        self._s3_options[name] = options

        define_attachment_accessors(name)
        attr_reader :_s3_attachments
        include InstanceMethods
      end

      def define_attachment_accessors(name)
        define_method(name) do
          unless @_s3_attachments and @_s3_attachments[name]
            @_s3_attachments = { name => {} }
            resp = s3_client.get_object(
              bucket: _s3_options[name][:bucket],
              key: s3_attachment_key(name)
            )
            @_s3_attachments[name][:value] = resp.body.read
          end
          @_s3_attachments[name][:value]
        end

        define_method("#{name}=") do |value|
          @_s3_attachments ||= {}
          @_s3_attachments[name] ||= {}
          @_s3_attachments[name].update(value: value, dirty: true)
          value
        end

        define_method("#{name}_url") do
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
