require 'spec_helper'

class CouchLogItem
  include SimplyCouch::Model
  has_s3_attachment :log_data, bucket: 'bucket-for-monsieur', access_key: 'abcdef', secret_access_key: 'secret!'
end

describe 'S3 attachment' do
  let(:client) { instance_double(Aws::S3::Client) }

  before do
    CouchLogItem._s3_options[:log_data][:bucket] = 'bucket-for-monsieur'
    CouchLogItem._s3_options[:log_data][:location] = :us
    CouchLogItem._s3_options[:log_data][:permissions] = 'private'
    CouchLogItem._s3_options[:log_data][:after_delete] = :nothing
    CouchLogItem._s3_options[:log_data][:logger] = nil

    allow(Aws::S3::Client).to receive(:new).and_return(client)
    allow(client).to receive(:put_object)
    allow(client).to receive(:delete_object)
  end

  let(:log_item) do
    item = CouchLogItem.new
    item.instance_variable_set(:@_s3_client, nil)
    item.instance_variable_set(:@_s3_bucket, nil)
    item
  end

  context 'when saving the attachment' do
    it 'creates an S3 client' do
      log_item.log_data = 'Yay! It logged!'
      expect(Aws::S3::Client).to receive(:new).with(
        access_key_id: 'abcdef',
        secret_access_key: 'secret!',
        region: 'us-east-1',
        logger: nil
      ).and_return(client)
      allow(client).to receive(:head_bucket)
      log_item.save
    end

    it 'uploads the file' do
      log_item.log_data = 'Yay! It logged!'
      allow(client).to receive(:head_bucket)
      expect(client).to receive(:put_object).with(
        bucket: 'bucket-for-monsieur',
        key: anything,
        body: 'Yay! It logged!',
        acl: 'private'
      )
      log_item.save
    end

    it 'also uploads on save!' do
      log_item.log_data = 'Yay! It logged!'
      allow(client).to receive(:head_bucket)
      expect(client).to receive(:put_object)
      log_item.save!
    end

    it 'uses the specified bucket' do
      CouchLogItem._s3_options[:log_data][:bucket] = 'mybucket'
      log_item.log_data = 'Yay! It logged!'
      expect(client).to receive(:head_bucket).with(bucket: 'mybucket')
      expect(client).to receive(:put_object).with(hash_including(bucket: 'mybucket'))
      log_item.save
    end

    it 'creates the bucket if it does not exist' do
      CouchLogItem._s3_options[:log_data][:bucket] = 'mybucket'
      log_item.log_data = 'Yay! log me'
      expect(client).to receive(:head_bucket).with(bucket: 'mybucket')
        .and_raise(Aws::S3::Errors::NoSuchBucket.new(nil, 'NoSuchBucket'))
      expect(client).to receive(:create_bucket).with(
        bucket: 'mybucket',
        create_bucket_configuration: nil
      )
      allow(client).to receive(:put_object)
      log_item.save
    end

    it 'creates an EU bucket with location constraint' do
      CouchLogItem._s3_options[:log_data][:bucket] = 'mybucket'
      CouchLogItem._s3_options[:log_data][:location] = :eu
      log_item.log_data = 'Yay! log me'
      expect(client).to receive(:head_bucket).with(bucket: 'mybucket')
        .and_raise(Aws::S3::Errors::NoSuchBucket.new(nil, 'NoSuchBucket'))
      expect(client).to receive(:create_bucket).with(
        bucket: 'mybucket',
        create_bucket_configuration: { location_constraint: 'eu-west-1' }
      )
      allow(client).to receive(:put_object)
      log_item.save
    end

    it 'raises an error if the bucket is not ours' do
      CouchLogItem._s3_options[:log_data][:bucket] = 'mybucket'
      CouchLogItem._s3_options[:log_data][:location] = :eu
      log_item.log_data = 'Yay! log me too'
      expect(client).to receive(:head_bucket).with(bucket: 'mybucket')
        .and_raise(Aws::S3::Errors::NoSuchBucket.new(nil, 'NoSuchBucket'))
      expect(client).to receive(:create_bucket).with(
        bucket: 'mybucket',
        create_bucket_configuration: { location_constraint: 'eu-west-1' }
      ).and_raise(Aws::S3::Errors::BucketAlreadyExists.new(nil, 'BucketAlreadyExists'))

      expect { log_item.save }.to raise_error(ArgumentError)
    end

    it 'passes the logger to the S3 client' do
      log_item.log_data = 'Yay! log me'
      CouchLogItem._s3_options[:log_data][:bucket] = 'mybucket'
      CouchLogItem._s3_options[:log_data][:logger] = Logger.new(nil)

      expect(Aws::S3::Client).to receive(:new).with(
        access_key_id: 'abcdef',
        secret_access_key: 'secret!',
        region: 'us-east-1',
        logger: kind_of(Logger)
      ).and_return(client)
      allow(client).to receive(:head_bucket)
      log_item.save
      CouchLogItem._s3_options[:log_data][:logger] = nil
    end

    it 'does not upload when not changed' do
      allow(client).to receive(:head_bucket)
      expect(client).not_to receive(:put_object)
      log_item.save
    end

    it 'uses full class name and id as key' do
      log_item.log_data = 'Yay!'
      allow(client).to receive(:head_bucket)
      expect(client).to receive(:put_object).with(hash_including(key: /couch_log_items\/log_data\//))
      log_item.save
    end

    it 'marks attachment not dirty after upload' do
      log_item.log_data = 'Yay!'
      allow(client).to receive(:head_bucket)
      log_item.save
      expect(log_item.instance_variable_get(:@_s3_attachments)[:log_data][:dirty]).to be_falsy
    end

    it 'stores attachment when validations succeed' do
      log_item.log_data = 'Yay!'
      allow(client).to receive(:head_bucket)
      expect(client).to receive(:put_object)
      log_item.save
    end

    it 'does not store attachment when validations fail' do
      log_item.log_data = 'Yay!'
      allow(client).to receive(:head_bucket)
      allow(log_item).to receive(:valid?).and_return(false)
      expect(client).not_to receive(:put_object)
      log_item.save
    end

    it 'serializes non-string data to json' do
      log_item.log_data = ['one log entry', 'and another one']
      allow(client).to receive(:head_bucket)
      expect(client).to receive(:put_object).with(hash_including(body: '["one log entry","and another one"]'))
      log_item.save
    end

    context 'attachment size' do
      before do
        allow(client).to receive(:head_bucket)
      end

      it 'stores on upload' do
        log_item.log_data = 'abc'
        log_item.save
        expect(log_item.log_data_size).to eq 3
      end

      it 'updates size on change' do
        log_item.log_data = 'abc'
        log_item.save
        expect(log_item.log_data_size).to eq 3
        log_item.log_data = 'example'
        log_item.save
        expect(log_item.log_data_size).to eq 7
      end

      it 'stores size of json attachments' do
        log_item.log_data = ['abc']
        log_item.save
        expect(log_item.log_data_size).to eq ['abc'].to_json.size
      end
    end
  end

  context 'when fetching the data' do
    let(:resp) { double('response', body: double(read: 'Yay!')) }

    before do
      allow(client).to receive(:get_object).and_return(resp)
    end

    it 'creates a configured S3 connection' do
      CouchLogItem._s3_options[:log_data][:bucket] = 'mybucket'
      CouchLogItem._s3_options[:log_data][:location] = :eu

      expect(Aws::S3::Client).to receive(:new).with(
        access_key_id: 'abcdef',
        secret_access_key: 'secret!',
        region: 'eu-west-1',
        logger: nil
      ).and_return(client)

      log_item.log_data
    end

    it 'fetches data from s3' do
      log_item.instance_variable_set(:@_s3_attachments, {})
      expect(client).to receive(:get_object).with(
        bucket: 'bucket-for-monsieur',
        key: anything
      ).and_return(resp)
      expect(log_item.log_data).to eq 'Yay!'
    end

    it 'does not mark attachment as dirty' do
      log_item.instance_variable_set(:@_s3_attachments, {})
      log_item.log_data
      expect(log_item._s3_attachments[:log_data][:dirty]).to be_falsy
    end

    it 'does not fetch if already set' do
      log_item.log_data = 'Yay!'
      expect(client).not_to receive(:get_object)
      expect(log_item.log_data).to eq 'Yay!'
    end
  end

  context 'when deleting' do
    before do
      CouchLogItem._s3_options[:log_data][:after_delete] = :nothing
      allow(client).to receive(:head_bucket)
      log_item.log_data = 'Yatzzee'
      log_item.save
    end

    it 'does nothing to S3' do
      expect(client).not_to receive(:delete_object)
      log_item.delete
    end

    it 'deletes on S3 if configured' do
      CouchLogItem._s3_options[:log_data][:after_delete] = :delete
      expect(client).to receive(:delete_object).with(
        bucket: 'bucket-for-monsieur',
        key: anything
      )
      log_item.delete
    end
  end
end
