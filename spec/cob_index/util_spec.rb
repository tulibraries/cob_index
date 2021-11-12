#frozen_string_literal: true

RSpec.describe CobIndex::Util do
  describe "#load_list_file" do
    it "can load a list from file in the list folder" do
      lines = subject.load_list_file("corporate_names")
      expect(lines).to be_an(Array)
    end

    it "also works with .txt at end of filename" do
      lines = subject.load_list_file("corporate_names.txt")
      expect(lines).to be_an(Array)
    end
  end
end
