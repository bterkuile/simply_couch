require 'spec_helper'

describe SimplyCouch::Model::Persistence::TypeCaster do
  let(:caster) { described_class.new }

  it 'casts back Time values to UTC iso8601' do
    local = Time.new(1981, 3, 9, 14, 22, 2, '+01:00')
    expect(caster.cast_back(local)).to eq('1981-03-09T13:22:02Z')
  end

  it 'casts back Date values via iso8601' do
    date = Date.new(1981, 3, 9)
    expect(caster.cast_back(date)).to eq('1981-03-09')
  end

  it 'returns plain values unchanged' do
    expect(caster.cast_back('abc')).to eq('abc')
  end
end
