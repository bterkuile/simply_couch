require 'spec_helper'

class CustomViewUser
  include SimplyCouch::Model

  property :tags
  view :by_tags, type: SimplyCouch::Model::Views::ArrayPropertyViewSpec, key: :tags
end

describe 'Custom couch views' do
  context 'with array views' do
    it 'finds objects with one match of the array' do
      CustomViewUser.create(tags: ['agile', 'cool', 'extreme'])
      CustomViewUser.create(tags: ['agile'])
      expect(CustomViewUser.find_all_by_tags('agile').size).to eq 2
    end

    it 'finds the object when the property is not an array' do
      CustomViewUser.create(tags: 'agile')
      expect(CustomViewUser.find_all_by_tags('agile').size).to eq 1
    end
  end
end
