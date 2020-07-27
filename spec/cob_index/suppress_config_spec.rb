# frozen_string_literal: true

require "traject/array_writer"

RSpec.describe "Suppress configuration" do
  let(:indexer) do
    settings = {
      "nokogiri.each_record_xpath" => "//oai:record",
      "nokogiri.namespaces" => { "oai" => "http://www.openarchives.org/OAI/2.0/" },
      "solr.url" => "http://example.com/solr",
      "writer" => Traject::ArrayWriter.new,
    }

    indexer = CobIndex::NokogiriIndexer.new(settings)
    indexer.load_config_file("lib/cob_index/suppress_config.rb")
    indexer
  end
  let(:oai_xml) do
    <<~EOT
    <?xml version="1.0" encoding="UTF-8"?>
    <OAI-PMH xmlns="http://www.openarchives.org/OAI/2.0/" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="http://www.openarchives.org/OAI/2.0/ http://www.openarchives.org/OAI/2.0/OAI-PMH.xsd">
      <responseDate>2020-03-03T04:16:09Z</responseDate>
      <request verb="ListRecords" metadataPrefix="marc21" set="blacklight" from="2020-03-02T20:47:11Z">https://na02.alma.exlibrisgroup.com/view/oai/01TULI_INST/request</request>
      <ListRecords>
      #{record_text}
      </ListRecords>
    </OAI-PMH>
    EOT
  end
  let(:records_file) { StringIO.new(oai_xml) }
  let(:records) { Traject::NokogiriReader.new(records_file, []) }
  let(:record) { records.first }

  before do
    stub_const("ENV", ENV.to_hash.merge("SOLR_URL" => "http://example.com/solr"))
  end


  context "record status = something not 'deleted'" do
    let(:record_text) {
      <<~EOT
      <record>
        <header status="not-deleted">
          <identifier>oai:alma.01TULI_INST:991022366369703811</identifier>
          <datestamp>2020-03-03T03:54:35Z</datestamp>
          <setSpec>blacklight</setSpec>
          <setSpec>rapid_print_journals</setSpec>
          <setSpec>blacklight_qa</setSpec>
        </header>
      </record>
      EOT
    }

    it "will skip the record" do
      expect(indexer.process_record(record).skip?).to eq(true)
    end
  end

  context "record status = 'deleted'" do
    let(:record_text) {
      <<~EOT
      <record>
        <header status="deleted">
          <identifier>oai:alma.01TULI_INST:991022366369703811</identifier>
          <datestamp>2020-03-03T03:54:35Z</datestamp>
          <setSpec>blacklight</setSpec>
          <setSpec>rapid_print_journals</setSpec>
          <setSpec>blacklight_qa</setSpec>
        </header>
      </record>
      EOT
    }

    it "will not skip record and process it as expected" do
      context = indexer.process_record(record)
      expect(context.skip?).to eq(false)
      expect(context.output_hash).to eq({
        "id" => ["991022366369703811"],
        "record_update_date" => ["2020-03-03T03:54:35Z"],
      })

    end
  end
end
