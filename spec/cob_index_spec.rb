# frozen_string_literal: true

RSpec.describe CobIndex do
  it "has a version number" do
    expect(CobIndex::VERSION).not_to be nil
  end

  describe "ingest" do
    before(:example) do
      @indexer = instance_double("Traject::Indexer::MarcIndexer")

      allow(Traject::Indexer::MarcIndexer).to receive(:new).and_return(@indexer)
      allow(@indexer).to receive_messages(load_config_file: nil, process: nil)
    end

    after(:example) do
      CobIndex::CLI.ingest
    end

    it "loads indexer" do
      expect(@indexer).to receive(:load_config_file)
      expect(@indexer).to receive(:process)
    end
  end
end
