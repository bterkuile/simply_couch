require 'spec_helper'

describe 'has_local_attached' do
  before do
    class DefaultStyleTest
      include SimplyCouch::Model
      property :title
      has_local_attached :file, default_style: :not_original
    end
  end

  it 'uses default_style when no style given for url' do
    obj = DefaultStyleTest.new
    obj.file_file_name = 'test.jpg'

    expect(obj.file.url).to eq '/system/file/tmp/not_original.jpg'
  end

  it 'uses default_style when no style given for path' do
    obj = DefaultStyleTest.new
    obj.file_file_name = 'test.jpg'

    expect(obj.file.url).to end_with '/system/file/tmp/not_original.jpg'
  end

  it 'allows explicit style override' do
    obj = DefaultStyleTest.new
    obj.file_file_name = 'test.jpg'

    expect(obj.file.url(:thumb)).to eq '/system/file/tmp/thumb.jpg'
  end

  it 'uses default_style from attachment_registry' do
    config = DefaultStyleTest.attachment_registry[:file]
    expect(config[:default_style]).to eq :not_original
  end
end
