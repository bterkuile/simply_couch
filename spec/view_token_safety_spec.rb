require 'spec_helper'

describe "CouchDB view token safety" do
  describe "SimplyCouch.assert_safe_view_token!" do
    it "passes valid class / association / property names through unchanged" do
      expect {
        SimplyCouch.assert_safe_view_token!('User', :posts, 'Namespaced::Thing', :editor_id, nil)
      }.not_to raise_error
    end

    it "accepts nested arrays and ignores nil/empty tokens" do
      expect {
        SimplyCouch.assert_safe_view_token!([:locale, nil], '', :position)
      }.not_to raise_error
    end

    it "raises on characters that could break out of the generated JavaScript" do
      ["a'b", 'a"b', 'a\\b', "a;b", "a)b", "a{b", "a(b", "a\nb"].each do |bad|
        expect {
          SimplyCouch.assert_safe_view_token!(bad)
        }.to raise_error(SimplyCouch::Error), "expected #{bad.inspect} to be rejected"
      end
    end
  end

  it "rejects an association declared with an unsafe name at definition time" do
    expect {
      Class.new do
        include SimplyCouch::Model
        belongs_to :"evil'); emit(doc,1);//"
      end
    }.to raise_error(SimplyCouch::Error)
  end
end
