# frozen_string_literal: true


RSpec.describe CobIndex::CoreExtensions::Array::Transformation do

  describe "Array::to_regex" do
    it "can transfrom to a regex" do
      expect(["hello", "world(s)"].to_regex).to eq(/hello|world\(s\)/i)
    end
  end
end
