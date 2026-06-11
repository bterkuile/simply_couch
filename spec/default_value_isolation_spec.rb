require 'spec_helper'

describe "Default value isolation" do
  # Directory (has_ancestry) declares `property :path_ids, type: Array, default: []`.
  # Each instance must get its own copy of the default, never a shared array.
  it "does not share a mutable Array default across instances" do
    a = Directory.new
    b = Directory.new
    a.path_ids << 'x'
    b.path_ids.should eq([])
    a.path_ids.should eq(['x'])
  end

  it "gives each instance an independent default object" do
    a = Directory.new
    b = Directory.new
    a.path_ids.object_id.should_not eq(b.path_ids.object_id)
  end
end
