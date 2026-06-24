# frozen_string_literal: true
#
# The contract every SimplyCouch::Adapter must satisfy, as shared examples.
# A backend proves parity by including it:
#
#   RSpec.describe SimplyCouch::Adapters::CouchRest do
#     it_behaves_like 'a simply_couch adapter'
#   end
#
# This same file is what the simply_couch-couchbase gem runs against a live
# Couchbase to demonstrate the backend is swappable. It assumes the suite's
# before(:each) leaves SimplyCouch.database pointing at a fresh, empty store.

# A minimal model used only by the contract — independent of the fixture graph
# so the examples port cleanly to any backend.
class ContractWidget
  include SimplyCouch::Model
  property :title
  property :score, type: Integer
  validates :title, presence: true
end

RSpec.shared_examples 'a simply_couch adapter' do
  let(:adapter) { SimplyCouch.database }

  def build_widget(attrs = {})
    ContractWidget.new({ title: 'a' }.merge(attrs))
  end

  describe '#save_document + #load_document' do
    it 'persists a new document and assigns _id/_rev' do
      w = build_widget(title: 'hello', score: 3)
      expect(adapter.save_document(w)).to eq(true)
      expect(w._id).not_to be_nil
      expect(w._rev).not_to be_nil
    end

    it 'reconstructs the stored doc into its model class via the ruby_class tag' do
      w = build_widget(title: 'hello', score: 7)
      adapter.save_document(w)
      loaded = adapter.load_document(w._id)
      expect(loaded).to be_a(ContractWidget)
      expect(loaded.title).to eq('hello')
      expect(loaded.score).to eq(7)
      expect(loaded.database).to eq(adapter)
    end

    it 'returns nil (does not raise) when the id is absent' do
      expect(adapter.load_document('does-not-exist')).to be_nil
    end

    it 'refuses to persist an invalid document' do
      expect(adapter.save_document(build_widget(title: nil))).to eq(false)
    end

    it 'updates an existing doc and rolls _rev forward' do
      w = build_widget(title: 'v1')
      adapter.save_document(w)
      first_rev = w._rev
      w.title = 'v2'
      adapter.save_document(w)
      expect(w._rev).not_to eq(first_rev)
      expect(adapter.load_document(w._id).title).to eq('v2')
    end
  end

  describe '#destroy_document' do
    it 'removes the document' do
      w = build_widget
      adapter.save_document(w)
      id = w._id
      adapter.destroy_document(w)
      expect(adapter.load_document(id)).to be_nil
    end
  end

  describe 'bulk operations' do
    it 'bulk_saves, bulk_loads (reconstructed) and bulk_destroys' do
      a = build_widget(title: 'a')
      b = build_widget(title: 'b')
      result = adapter.bulk_save([a, b])
      expect(result[:saved].size).to eq(2)
      expect(a._id).not_to be_nil

      loaded = adapter.bulk_load([a._id, b._id])
      expect(loaded).to all(be_a(ContractWidget))
      expect(loaded.map(&:title).sort).to eq(%w[a b])

      adapter.bulk_destroy([a, b])
      expect(adapter.bulk_load([a._id, b._id])).to eq([])
    end

    it 'bulk_load drops ids that are missing' do
      a = build_widget
      adapter.save_document(a)
      expect(adapter.bulk_load([a._id, 'missing']).map(&:_id)).to eq([a._id])
    end
  end

  describe 'optimistic concurrency' do
    it 'maps a stale-write clash to SimplyCouch::Conflict' do
      w = build_widget(title: 'orig')
      adapter.save_document(w)
      stale = adapter.load_document(w._id)
      w.title = 'winner'
      adapter.save_document(w) # advances the stored revision
      stale.title = 'loser'
      expect { adapter.save_document(stale) }.to raise_error(SimplyCouch::Conflict)
    end
  end
end
