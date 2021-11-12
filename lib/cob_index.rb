# frozen_string_literal: true

require "traject"
require "alma/electronic/batch_utils"
require "logger"

module CobIndex
  autoload :Macros, "cob_index/macros"
  autoload :DefaultConfig, "cob_index/default_config"
  autoload :DotProperties, "cob_index/dot_properties"
  autoload :Version, "cob_index/version"
  autoload :NokogiriIndexer, "cob_index/nokogiri_indexer"
  autoload :Util, "cob_index/util"
  autoload :CoreExtensions, "cob_index/core_extensions"


  Array.include CoreExtensions::Array::Transformation

  module CLI
    def self.ingest(commit: false, marc_xml: "")
      indexer = Traject::Indexer::MarcIndexer.new("solr_writer.commit_on_close": commit)
      indexer.load_config_file("#{File.dirname(__FILE__)}/cob_index/indexer_config.rb")
      indexer.process(StringIO.new(marc_xml))
    end


    def self.delete(commit: false, suppress: false, xml: "")
      settings = {
        "nokogiri.each_record_xpath" => "//oai:record",
        "nokogiri.namespaces" => { "oai" => "http://www.openarchives.org/OAI/2.0/" },
        "solr_writer.commit_on_close" => commit
      }

      indexer = CobIndex::NokogiriIndexer.new(settings)
      config =
        if suppress
          "suppress_config"
        else
          "deletes_config"
        end
      indexer.load_config_file("#{File.dirname(__FILE__)}/cob_index/#{config}.rb")
      indexer.process(StringIO.new(xml))
    end


    def self.harvest(type = nil)
      Alma.configure { |config|
        # TODO: fix so tul_cob config overrides this.
        config.apikey = ENV["ALMA_API_KEY"]
        config.timeout = 300
      }

      ids =  Alma::Electronic.get_ids
        .map { |id| { collection_id: id.to_s } }

      # TODO: Use Alma.configuration.logger.
      logger = Logger.new(STDOUT)
      batch = Alma::Electronic::BatchUtils.new(ids: ids, logger: logger)

      batch.get_collection_notes
      batch.print_notes(filename: "collection_notes.json")

      batch.get_service_notes
      batch.print_notes(filename: "service_notes.json")
    end

    def self.commit
      indexer = Traject::Indexer::MarcIndexer.new
      indexer.load_config_file("#{File.dirname(__FILE__)}/cob_index/indexer_config.rb")
      indexer.writer.commit
    end
  end
end
