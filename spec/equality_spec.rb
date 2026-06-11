require 'spec_helper'

describe "Equality and hashing" do
  describe "unsaved records" do
    it "two distinct new records are not equal" do
      a = User.new(name: 'a')
      b = User.new(name: 'a')
      (a == b).should be false
      a.eql?(b).should be false
    end

    it "a new record equals itself" do
      a = User.new(name: 'a')
      (a == a).should be true
    end

    it "new records are distinct inside a Set / uniq / include?" do
      a = User.new(name: 'a')
      b = User.new(name: 'b')
      [a, b].uniq.size.should eq(2)
      Set.new([a, b]).size.should eq(2)
      [a].include?(b).should be false
    end
  end

  describe "persisted records" do
    it "two instances with the same _id and _rev are equal" do
      a = User.new(name: 'a')
      b = User.new(name: 'b')
      a._id = b._id = 'same-id'
      a._rev = b._rev = '1-abc'
      (a == b).should be true
      a.hash.should eq(b.hash)
    end

    it "same _id but different _rev are not equal" do
      a = User.new
      b = User.new
      a._id = b._id = 'same-id'
      a._rev = '1-abc'
      b._rev = '2-def'
      (a == b).should be false
    end
  end
end
