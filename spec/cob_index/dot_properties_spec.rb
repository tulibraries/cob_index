# frozen_string_literal: true

RSpec.describe CobIndex::DotProperties do

  describe "#load" do
    it "loads local properties" do
      properties = CobIndex::DotProperties.load("libraries_map")
      expect(properties["MAIN"]).to eq("Charles Library")
    end
  end
end
