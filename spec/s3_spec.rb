require 'spec_helper'

begin
  require 'right_aws'
rescue LoadError
  # Skip — right_aws gem not available
end

if defined?(RightAws)
  class CouchLogItem
    include SimplyCouch::Model
    has_s3_attachment :log_data, bucket: 'bucket-for-monsieur', access_key: 'abcdef', secret_access_key: 'secret!'
  end

  describe 'S3 attachment' do
    before do
      CouchLogItem.instance_variable_set(:@_s3_connection, nil)
      CouchLogItem._s3_options[:log_data][:ca_file] = nil

      bucket = stub(:bckt) do
        stubs(:put).returns(true)
        stubs(:get).returns(true)
      end

      @bucket = bucket

      @s3 = stub(:s3) do
        stubs(:bucket).returns(bucket)
      end

      RightAws::S3.stubs(:new).returns @s3
      @log_item = CouchLogItem.new
    end

    context 'when saving the attachment' do
      it 'fetches the collection' do
        @log_item.log_data = 'Yay! It logged!'
        RightAws::S3.expects(:new).with('abcdef', 'secret!', multi_thread: true, ca_file: nil, logger: nil).returns(@s3)
        @log_item.save
      end

      it 'uploads the file' do
        @log_item.log_data = 'Yay! It logged!'
        @bucket.expects(:put).with(anything, 'Yay! It logged!', {}, anything)
        @log_item.save
      end

      it 'also uploads on save!' do
        @log_item.log_data = 'Yay! It logged!'
        @bucket.expects(:put).with(anything, 'Yay! It logged!', {}, anything)
        @log_item.save!
      end

      it 'uses the specified bucket' do
        @log_item.log_data = 'Yay! It logged!'
        CouchLogItem._s3_options[:log_data][:bucket] = 'mybucket'
        @s3.expects(:bucket).with('mybucket').returns(@bucket)
        @log_item.save
      end

      it 'creates the bucket if it does not exist' do
        @log_item.log_data = 'Yay! log me'
        CouchLogItem._s3_options[:log_data][:bucket] = 'mybucket'
        @s3.expects(:bucket).with('mybucket').returns(nil)
        @s3.expects(:bucket).with('mybucket', true, 'private', location: nil).returns(@bucket)
        @log_item.save
      end

      it 'accepts :us location option but does not set it in RightAWS::S3' do
        @log_item.log_data = 'Yay! log me'
        CouchLogItem._s3_options[:log_data][:bucket] = 'mybucket'
        CouchLogItem._s3_options[:log_data][:location] = :us
        @s3.expects(:bucket).with('mybucket').returns(nil)
        @s3.expects(:bucket).with('mybucket', true, 'private', location: nil).returns(@bucket)
        @log_item.save
      end

      it 'raises an error if the bucket is not ours' do
        @log_item.log_data = 'Yay! log me too'
        CouchLogItem._s3_options[:log_data][:bucket] = 'mybucket'
        CouchLogItem._s3_options[:log_data][:location] = :eu
        @s3.expects(:bucket).with('mybucket').returns(nil)
        @s3.expects(:bucket).with('mybucket', true, 'private', location: :eu).raises(RightAws::AwsError, 'BucketAlreadyExists: The requested bucket name is not available. The bucket namespace is shared by all users of the system. Please select a different name and try again')
        expect { @log_item.save }.to raise_error(ArgumentError)
      end

      it 'passes the logger object down to RightAws' do
        logger = mock
        @log_item.log_data = 'Yay! log me'
        CouchLogItem._s3_options[:log_data][:bucket] = 'mybucket'
        CouchLogItem._s3_options[:log_data][:logger] = logger
        RightAws::S3.expects(:new).with(anything, anything, logger: logger, ca_file: nil, multi_thread: true).returns(@s3)
        @log_item.save
      end

      it 'does not upload the attachment when it has not been changed' do
        @bucket.expects(:put).never
        @log_item.save
      end

      it 'sets the permissions to private by default' do
        class Item
          include SimplyCouch::Model
          has_s3_attachment :log_data, bucket: 'mybucket'
        end
        @bucket.expects(:put).with(anything, anything, {}, 'private')
        @log_item = Item.new
        @log_item.log_data = 'Yay!'
        @log_item.save
      end

      it 'sets the permissions to whatever is specified in the options for the attachment' do
        @log_item.save
        old_perms = CouchLogItem._s3_options[:log_data][:permissions]
        CouchLogItem._s3_options[:log_data][:permissions] = 'public-read'
        @bucket.expects(:put).with(anything, anything, {}, 'public-read')
        @log_item.log_data = 'Yay!'
        @log_item.save
        CouchLogItem._s3_options[:log_data][:permissions] = old_perms
      end

      it 'uses the full class name and the id as key' do
        @log_item.save
        @bucket.expects(:put).with("couch_log_items/log_data/#{@log_item.id}", 'Yay!', {}, anything)
        @log_item.log_data = 'Yay!'
        @log_item.save
      end

      it 'marks the attachment as not dirty after uploading' do
        @log_item.log_data = 'Yay!'
        @log_item.save
        expect(@log_item.instance_variable_get(:@_s3_attachments)[:log_data][:dirty]).to be_falsy
      end

      it 'stores the attachment when the validations succeeded' do
        @log_item.log_data = 'Yay!'
        @log_item.stubs(:valid?).returns(true)
        @bucket.expects(:put)
        @log_item.save
      end

      it 'does not store the attachment when the validations failed' do
        @log_item.log_data = 'Yay!'
        @log_item.stubs(:valid?).returns(false)
        @bucket.expects(:put).never
        @log_item.save
      end

      it 'saves the attachment status' do
        @log_item.save
        @log_item.attributes['log_data_attachments']
      end

      it 'generates the url for the attachment' do
        @log_item._s3_options[:log_data][:bucket] = 'bucket-for-monsieur'
        @log_item._s3_options[:log_data][:permissions] = 'public-read'
        @log_item.save
        expect(@log_item.log_data_url).to eq "http://bucket-for-monsieur.s3.amazonaws.com/#{@log_item.s3_attachment_key(:log_data)}"
      end

      it 'adds a short-lived access key for private attachments' do
        @log_item._s3_options[:log_data][:bucket] = 'bucket-for-monsieur'
        @log_item._s3_options[:log_data][:location] = :us
        @log_item._s3_options[:log_data][:permissions] = 'private'
        @log_item.save
        expect(@log_item.log_data_url.tr('%2F', '/')).to include("https://bucket-for-monsieur.s3.amazonaws.com:443/#{@log_item.s3_attachment_key(:log_data)}")
        expect(@log_item.log_data_url).to include('Signature=')
        expect(@log_item.log_data_url).to include('Expires=')
      end

      it 'serializes data other than strings to json' do
        @log_item.log_data = ['one log entry', 'and another one']
        @bucket.expects(:put).with(anything, '["one log entry","and another one"]', {}, anything)
        @log_item.save
      end

      context 'when noting the size of the attachment' do
        it 'stores on upload' do
          @log_item.log_data = 'abc'
          @bucket.expects(:put)
          expect(@log_item.save).to be true
          expect(@log_item.log_data_size).to eq 3
        end

        it 'updates the size if the attachment gets updated' do
          @log_item.log_data = 'abc'
          @bucket.stubs(:put)
          expect(@log_item.save).to be true
          expect(@log_item.log_data_size).to eq 3
          @log_item.log_data = 'example'
          expect(@log_item.save).to be true
          expect(@log_item.log_data_size).to eq 7
        end

        it 'stores the size of json attachments' do
          @log_item.log_data = ['abc']
          @bucket.stubs(:put)
          expect(@log_item.save).to be true
          expect(@log_item.log_data_size).to eq ['abc'].to_json.size
        end
      end
    end

    context 'when fetching the data' do
      it 'creates a configured S3 connection' do
        CouchLogItem._s3_options[:log_data][:bucket] = 'mybucket'
        CouchLogItem._s3_options[:log_data][:location] = :eu
        CouchLogItem._s3_options[:log_data][:ca_file] = '/etc/ssl/ca.crt'
        RightAws::S3.expects(:new).with('abcdef', 'secret!', multi_thread: true, ca_file: '/etc/ssl/ca.crt', logger: nil).returns(@s3)
        @log_item.log_data
      end

      it 'fetches the data from s3 and sets the attachment attribute' do
        @log_item.instance_variable_set(:@_s3_attachments, {})
        @bucket.expects(:get).with("couch_log_items/log_data/#{@log_item.id}").returns('Yay!')
        expect(@log_item.log_data).to eq 'Yay!'
      end

      it 'does not mark the attachment as dirty' do
        @log_item.instance_variable_set(:@_s3_attachments, {})
        @bucket.expects(:get).with("couch_log_items/log_data/#{@log_item.id}").returns('Yay!')
        @log_item.log_data
        expect(@log_item._s3_attachments[:log_data][:dirty]).to be_falsy
      end

      it 'does not try to fetch the attachment if the value is already set' do
        @log_item.log_data = 'Yay!'
        @bucket.expects(:get).never
        expect(@log_item.log_data).to eq 'Yay!'
      end
    end

    context 'when deleting' do
      before do
        CouchLogItem._s3_options[:log_data][:after_delete] = :nothing
        @log_item.log_data = 'Yatzzee'
        @log_item.save
      end

      it 'does nothing to S3' do
        @bucket.expects(:key).never
        @log_item.delete
      end

      it 'also deletes on S3 if configured so' do
        CouchLogItem._s3_options[:log_data][:after_delete] = :delete
        s3_key = mock(delete: true)
        @bucket.expects(:key).with(@log_item.s3_attachment_key('log_data'), true).returns(s3_key)
        @log_item.delete
      end
    end
  end
end
