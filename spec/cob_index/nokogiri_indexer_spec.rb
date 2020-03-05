# frozen_string_literal: true

RSpec.describe CobIndex::NokogiriIndexer do
  let(:settings)  { {
    "nokogiri.each_record_xpath" => "/oai:OAI-PMH/oai:ListRecords/oai:record",
    "nokogiri.namespaces" => { "oai" => "http://www.openarchives.org/OAI/2.0/" },
    "solr_writer.commit_on_close" => "false",
  } }

  let(:record) { Traject::NokogiriReader.new(StringIO.new(
                                               <<-XML
<?xml version="1.0" encoding="UTF-8"?>
<OAI-PMH xmlns="http://www.openarchives.org/OAI/2.0/" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="http://www.openarchives.org/OAI/2.0/ http://www.openarchives.org/OAI/2.0/OAI-PMH.xsd">
  <responseDate>2020-03-03T04:16:09Z</responseDate>
  <request verb="ListRecords" metadataPrefix="marc21" set="blacklight" from="2020-03-02T20:47:11Z">https://na02.alma.exlibrisgroup.com/view/oai/01TULI_INST/request</request>
  <ListRecords>
    <record>
      <header status="deleted">
        <identifier>oai:alma.01TULI_INST:991025803889703811</identifier>
        <datestamp>2020-03-03T03:54:35Z</datestamp>
        <setSpec>blacklight</setSpec>
        <setSpec>rapid_print_journals</setSpec>
        <setSpec>blacklight_qa</setSpec>
      </header>
    </record>
  </ListRecords>
</OAI-PMH>
  XML
  ), []).first }

  let(:indexer) { CobIndex::NokogiriIndexer.new(settings) }

  describe "get_id" do
    it "successfully gets record id" do
      expect(indexer.get_id(record)).to eq("991025803889703811")
    end
  end

  describe "get_status" do
    it "successfully gets the record status" do
      expect(indexer.get_status(record)).to eq("deleted")
    end
  end

  describe "get_datestamp" do
    it "successfully gets the record datestamp" do
      expect(indexer.get_datestamp(record)).to eq("2020-03-03T03:54:35Z")
    end
  end
end
