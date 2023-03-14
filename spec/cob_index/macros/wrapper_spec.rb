# frozen_string_literal: true


require "rspec"
require "cob_index/macros/wrapper"

include CobIndex::Macros::Wrapper

RSpec.describe CobIndex::Macros::Wrapper  do

  describe "#flank(field)" do
    let(:input) {}
    subject { CobIndex::Macros::Wrapper.flank input }
    context "nil" do
      it "returns an empty string" do
        expect(subject).to be_nil
      end
    end

    context "empty string" do
      let(:input) { "" }
      it "returns an empty string" do
        expect(subject).to eq("")
      end
    end

    context "non empty string" do
      let(:input) { "foo bar buzz" }
      it "returns a flanked string" do
        expect(subject).to eq("matchbeginswithfoo foo bar buzz matchendswithbuzz")
      end
    end

    context "a string that is flanked" do
      let(:input) { "matchbeginswithfoo foo bar buzz matchendswithbar" }
      it "does not reflank a string" do
        expect(subject).to eq(input)
      end
    end
  end
end
