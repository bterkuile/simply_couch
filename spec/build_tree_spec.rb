require 'spec_helper'

describe "Ancestry.build_tree" do
  def node(id, path_ids, position = 0)
    d = Directory.new(name: id)
    d._id = id
    d.path_ids = path_ids
    d.position = position
    d
  end

  it "builds a tree from a flat list using path_ids" do
    root  = node('r',  ['r'])
    child = node('c',  ['r', 'c'])
    roots = Directory.build_tree([root, child])
    roots.map(&:id).should eq(['r'])
    roots.first.children.map(&:id).should eq(['c'])
  end

  it "does not leak a class-level @tree_wrapper after building" do
    Directory.build_tree([node('r', ['r'])])
    Directory.instance_variable_get(:@tree_wrapper).should be_nil
  end

  it "is safe under concurrent calls (no shared-state corruption)" do
    threads = (0...8).map do |i|
      Thread.new do
        root  = node("r#{i}", ["r#{i}"])
        child = node("c#{i}", ["r#{i}", "c#{i}"])
        roots = Directory.build_tree([root, child])
        [roots.map(&:id), roots.first.children.map(&:id)]
      end
    end
    results = threads.map(&:value)
    results.each_with_index do |(root_ids, child_ids), i|
      root_ids.should eq(["r#{i}"])
      child_ids.should eq(["c#{i}"])
    end
  end
end
