require 'spec_helper'

class CouchAttachmentDoc
  include SimplyCouch::Model
  property :title
  has_couch_attached :receipt
end

describe 'CouchDB attachments' do
  describe 'low-level API' do
    it 'puts and fetches an attachment' do
      doc = CouchAttachmentDoc.create(title: 'test')
      doc.put_couch_attachment('file.txt', 'hello world', content_type: 'text/plain')
      expect(doc.fetch_couch_attachment('file.txt')).to eq 'hello world'
    end

    it 'lists attachment names' do
      doc = CouchAttachmentDoc.create(title: 'test')
      doc.put_couch_attachment('a.txt', 'a')
      doc.put_couch_attachment('b.txt', 'b')
      expect(doc.couch_attachment_names).to contain_exactly('a.txt', 'b.txt')
    end

    it 'deletes an attachment' do
      doc = CouchAttachmentDoc.create(title: 'test')
      doc.put_couch_attachment('file.txt', 'data')
      doc.delete_couch_attachment('file.txt')
      expect(doc.couch_attachment?('file.txt')).to be false
    end

    it 'returns nil for missing attachment' do
      doc = CouchAttachmentDoc.create(title: 'test')
      expect(doc.fetch_couch_attachment('missing.txt')).to be_nil
    end
  end

  describe 'has_couch_attached macro' do
    it 'defines getter and setter' do
      doc = CouchAttachmentDoc.new
      expect(doc).to respond_to(:receipt)
      expect(doc).to respond_to(:receipt=)
    end

    it 'defines URL helper' do
      doc = CouchAttachmentDoc.new
      expect(doc).to respond_to(:receipt_url)
    end

    it 'defines metadata properties' do
      doc = CouchAttachmentDoc.new
      expect(doc).to respond_to(:receipt_content_type)
      expect(doc).to respond_to(:receipt_content_type=)
      expect(doc).to respond_to(:receipt_size)
      expect(doc).to respond_to(:receipt_size=)
    end

    it 'stores and retrieves data through the setter/getter' do
      doc = CouchAttachmentDoc.create(title: 'test')
      doc.receipt = 'binary data here'
      doc.save

      reloaded = CouchAttachmentDoc.find(doc.id)
      expect(reloaded.receipt).to eq 'binary data here'
    end

    it 'tracks content type' do
      doc = CouchAttachmentDoc.create(title: 'test')
      doc.receipt = 'data'
      doc.save
      expect(doc.receipt_content_type).to eq 'binary/octet-stream'
    end

    it 'tracks size' do
      doc = CouchAttachmentDoc.create(title: 'test')
      doc.receipt = '12345'
      doc.save
      expect(doc.receipt_size).to eq 5
    end

    it 'handles non-persisted records via pending queue' do
      doc = CouchAttachmentDoc.new(title: 'draft')
      doc.receipt = 'pending data'
      result = doc.save

      expect(result).to be_truthy
      reloaded = CouchAttachmentDoc.find(doc.id)
      expect(reloaded.receipt).to eq 'pending data'
    end

    it 'updates attachment on second assignment' do
      doc = CouchAttachmentDoc.create(title: 'test')
      doc.receipt = 'v1'
      doc.save

      doc.receipt = 'v2'
      doc.save

      reloaded = CouchAttachmentDoc.find(doc.id)
      expect(reloaded.receipt).to eq 'v2'
    end

    it 'generates a URL' do
      doc = CouchAttachmentDoc.create(title: 'test')
      doc.receipt = 'data'
      doc.save

      url = doc.receipt_url
      expect(url).to include(doc._id)
      expect(url).to include('receipt')
    end
  end
end
