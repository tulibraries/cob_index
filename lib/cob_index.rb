# frozen_string_literal: true

require "cob_index/version"
require "cob_index/dot_properties"
require "cob_index/nokogiri_indexer"
require "traject"


module CobIndex
  module CLI
    def self.ingest(commit: false, marc_xml: "")
      indexer = Traject::Indexer::MarcIndexer.new("solr_writer.commit_on_close": commit)
      indexer.load_config_file("#{File.dirname(__FILE__)}/cob_index/indexer_config.rb")
      indexer.process(StringIO.new(marc_xml))
    end


    def self.delete(commit: false, xml: "")
      settings = {
        "nokogiri.each_record_xpath" => "/oai:OAI-PMH/oai:ListRecords/oai:record",
        "nokogiri.namespaces" => { "oai" => "http://www.openarchives.org/OAI/2.0/" },
        "solr_writer.commit_on_close" => commit
      }

      indexer = CobIndex::NokogiriIndexer.new(settings)
      indexer.load_config_file("#{File.dirname(__FILE__)}/cob_index/delete_config.rb")
      indexer.process(StringIO.new(xml))
    end
  end
end
