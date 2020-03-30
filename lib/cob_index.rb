# frozen_string_literal: true

require "cob_index/version"
require "cob_index/dot_properties"
require "cob_index/nokogiri_indexer"
require "traject"
require "alma/electronic/batch_utils"
require "logger"



module CobIndex
  module CLI
    def self.ingest(commit: false, marc_xml: "")
      indexer = Traject::Indexer::MarcIndexer.new("solr_writer.commit_on_close": commit)
      indexer.load_config_file("#{File.dirname(__FILE__)}/cob_index/indexer_config.rb")
      indexer.process(StringIO.new(marc_xml))
    end


    def self.delete(commit: false, xml: "")
      settings = {
        "nokogiri.each_record_xpath" => "//oai:record",
        "nokogiri.namespaces" => { "oai" => "http://www.openarchives.org/OAI/2.0/" },
        "solr_writer.commit_on_close" => commit
      }

      indexer = CobIndex::NokogiriIndexer.new(settings)
      indexer.load_config_file("#{File.dirname(__FILE__)}/cob_index/delete_config.rb")
      indexer.process(StringIO.new(xml))
    end


    def self.harvest(type = nil)
      Alma.configure { |config|
        # TODO: fix so tul_cob config overrides this.
        config.apikey = ENV["ALMA_API_KEY"]
        config.timeout = 20
      }

      logger = Logger.new(STDOUT)

      ids =  Alma::Electronic.get_ids
        .map { |id| { collection_id: id.to_s } }

      batch = Alma::Electronic::BatchUtils.new(ids: ids, logger: logger)

      batch.get_collection_notes
      batch.print_notes(filename: "collection_notes.json")

      batch.get_service_notes
      batch.print_notes(filename: "service_notes.json")
    end
  end
end
