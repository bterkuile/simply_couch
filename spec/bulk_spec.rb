require 'spec_helper'

# DRAFT: requires a live CouchDB (like the rest of the suite). These specs
# document the intended contract of the bulk-write API.
describe "Bulk write API" do
  describe ".save_all" do
    it "persists multiple new records in one call and assigns _id/_rev" do
      result = User.save_all([User.new(name: 'a'), User.new(name: 'b')])
      result[:saved].size.should eq(2)
      result[:invalid].should be_empty
      result[:saved].each do |record|
        record._id.should_not be_nil
        record._rev.should_not be_nil
        record.new?.should be false
      end
    end

    it "sets timestamps on new records" do
      record = User.new(name: 'a')
      User.save_all([record])
      record.created_at.should_not be_nil
      record.updated_at.should_not be_nil
    end
  end

  describe ".create_all" do
    it "builds and persists records from attribute hashes" do
      result = User.create_all([{ name: 'a' }, { name: 'b' }])
      result[:saved].map(&:name).sort.should eq(['a', 'b'])
    end
  end

  describe ".destroy_all" do
    it "deletes persisted records in one call and clears their ids" do
      records = User.save_all([User.new(name: 'a'), User.new(name: 'b')])[:saved]
      User.destroy_all(records)
      records.each { |r| r._id.should be_nil }
    end
  end
end
