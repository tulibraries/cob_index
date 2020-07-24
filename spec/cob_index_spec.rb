# frozen_string_literal: true

RSpec.describe CobIndex do
  it "has a version number" do
    expect(CobIndex::VERSION).not_to be nil
  end

  describe "ingest" do
    before(:example) do
      @indexer = instance_double("Traject::Indexer::MarcIndexer")
      @io = instance_double(IO)

      allow(Traject::Indexer::MarcIndexer).to receive(:new).and_return(@indexer)
      allow(@indexer).to receive_messages(load_config_file: "", process: "")
      allow(@io).to receive_messages(read: "")
      allow(CobIndex::CLI).to receive_messages(open: @io)
    end

    after(:example) do
      CobIndex::CLI.ingest
    end

    it "loads indexer" do
      expect(@indexer).to receive(:load_config_file)
      expect(@indexer).to receive(:process)
    end

    context "commit is not set" do
      it "passes solr_writer.commit_on_close: false by default" do
        expect(Traject::Indexer::MarcIndexer).to receive(:new).with("solr_writer.commit_on_close": false)
      end
    end


    context "commit is true" do
      it "passes solr_writer.commit_on_close: true" do
        expect(Traject::Indexer::MarcIndexer).to receive(:new).with("solr_writer.commit_on_close": true)
        CobIndex::CLI.ingest(commit: true, marc_xml: "")
      end
    end
  end

  describe "delete" do
    let(:xml) { "" }

    before(:example) do
      @indexer = instance_double("CobIndex::NokogiriIndexer")

      allow(CobIndex::NokogiriIndexer).to receive(:new).and_return(@indexer)
      allow(@indexer).to receive_messages(load_config_file: "", process: "")
      allow(CobIndex::CLI).to receive_messages(open: @io)
    end

    after(:example) do
      CobIndex::CLI.delete(xml: "")
    end

    it "loads indexer" do
      expect(@indexer).to receive(:load_config_file)
      expect(@indexer).to receive(:process)
    end

    context "commit is not set" do
      it "passes solr_writer.commit_on_close: false by default" do
        expect(CobIndex::NokogiriIndexer).to receive(:new).with(
          "nokogiri.each_record_xpath" => "//oai:record",
          "nokogiri.namespaces" => { "oai" => "http://www.openarchives.org/OAI/2.0/" },
          "solr_writer.commit_on_close" => false,
        )
      end
    end


    context "commit is true" do
      it "passes solr_writer.commit_on_close: true" do
        expect(CobIndex::NokogiriIndexer).to receive(:new).with(
          "nokogiri.each_record_xpath" => "//oai:record",
          "nokogiri.namespaces" => { "oai" => "http://www.openarchives.org/OAI/2.0/" },
          "solr_writer.commit_on_close" => true,
        )
        CobIndex::CLI.delete(commit: true, xml: "")
      end
    end
  end

  describe "harvest" do
    let(:xml) { "" }

    before(:example) do
      allow(Alma::Electronic).to receive(:get_ids).and_return([])
    end


    it "does not fail smoke test" do
      CobIndex::CLI.harvest()
    end
  end

  describe "commit" do
    let(:writer) { instance_double(Traject::SolrJsonWriter) }

    it "sends a commit to solr" do
      allow(Traject::SolrJsonWriter).to receive(:new) { writer }
      allow(writer).to receive(:commit) { "committed" }

      expect(CobIndex::CLI.commit).to eq("committed")
    end
  end
end
