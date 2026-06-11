require 'spec_helper'

# Requires a live CouchDB (like the rest of the suite).
# Note: User validates_presence_of :title, so test records must set :title,
# otherwise save_all correctly rejects them as invalid and persists nothing.
describe "Bulk write API" do
  describe ".save_all" do
    it "persists multiple new records in one call and assigns _id/_rev" do
      result = User.save_all([User.new(title: 'a'), User.new(title: 'b')])
      result[:saved].size.should eq(2)
      result[:invalid].should be_empty
      result[:saved].each do |record|
        record._id.should_not be_nil
        record._rev.should_not be_nil
        record.new?.should be false
      end
    end

    it "sets timestamps on new records" do
      record = User.new(title: 'a')
      User.save_all([record])
      record.created_at.should_not be_nil
      record.updated_at.should_not be_nil
    end

    it "reports invalid records under :invalid and does not persist them" do
      result = User.save_all([User.new(title: 'ok'), User.new(name: 'no title')])
      result[:saved].size.should eq(1)
      result[:invalid].size.should eq(1)
      result[:invalid].first.new?.should be true
    end
  end

  describe ".create_all" do
    it "builds and persists records from attribute hashes" do
      result = User.create_all([{ title: 'a' }, { title: 'b' }])
      result[:saved].map(&:title).sort.should eq(['a', 'b'])
    end
  end

  describe ".destroy_all" do
    it "deletes persisted records in one call and clears their ids" do
      records = User.save_all([User.new(title: 'a'), User.new(title: 'b')])[:saved]
      records.size.should eq(2)
      User.destroy_all(records)
      records.each { |r| r._id.should be_nil }
    end
  end
end
