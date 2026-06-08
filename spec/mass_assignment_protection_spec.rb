require 'spec_helper'

describe 'Mass assignment protection' do
  context 'when using attr_protected' do
    before do
      Category.instance_eval do
        @_accessible_attributes = []
        attr_protected :parent, :alias
      end
    end

    it 'does not allow to set with mass assignment using attributes=' do
      item = Category.new
      item.attributes = { parent: 'a', name: 'c' }
      expect(item.name).to eq 'c'
      expect(item.parent).to be_nil
    end

    it 'does not allow to set with mass assignment using attributes= - ignore string vs. symbol' do
      item = Category.new
      item.attributes = { 'parent' => 'a', 'name' => 'c' }
      expect(item.name).to eq 'c'
      expect(item.parent).to be_nil
    end

    it 'does not allow to set with mass assignment using the constructor' do
      item = Category.new(parent: 'a', name: 'c')
      expect(item.name).to eq 'c'
      expect(item.parent).to be_nil
    end

    it 'does not allow to set with mass assignment using update_attributes' do
      item = Category.new
      item.update_attributes(parent: 'a', name: 'c')
      expect(item.name).to eq 'c'
      expect(item.parent).to be_nil
    end
  end

  context 'attr_accessible' do
    before do
      Category.instance_eval do
        @_protected_attributes = []
        attr_accessible :name
      end
    end

    it 'does not allow to set with mass assignment using attributes=' do
      item = Category.new
      item.attributes = { parent: 'a', name: 'c' }
      expect(item.name).to eq 'c'
      expect(item.parent).to be_nil
    end

    it 'does not allow to set with mass assignment using the constructor' do
      item = Category.new(parent: 'a', name: 'c')
      expect(item.name).to eq 'c'
      expect(item.parent).to be_nil
    end

    it 'does not allow to set with mass assignment using update_attributes' do
      item = Category.new
      item.update_attributes(parent: 'a', name: 'c')
      expect(item.name).to eq 'c'
      expect(item.parent).to be_nil
    end
  end
end
