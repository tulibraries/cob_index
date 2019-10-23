# frozen_string_literal: true

require "cob_index/version"
require "cob_index/dot_properties"
require "traject"

module CobIndex
  module CLI
    def self.ingest
      indexer = Traject::Indexer::MarcIndexer.new("solr_writer.commit_on_close": false)
      indexer.load_config_file("#{File.dirname(__FILE__)}/cob_index/indexer_config.rb")
      indexer.process(StringIO.new(open(ARGV[0]).read))
    end
  end
end
