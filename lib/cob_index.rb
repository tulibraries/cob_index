# frozen_string_literal: true

require "traject"
require "alma/electronic/batch_utils"
require "logger"

module CobIndex
  autoload :CLI, "cob_index/cli"
  autoload :CoreExtensions, "cob_index/core_extensions"
  autoload :DefaultConfig, "cob_index/default_config"
  autoload :DotProperties, "cob_index/dot_properties"
  autoload :Macros, "cob_index/macros"
  autoload :NokogiriIndexer, "cob_index/nokogiri_indexer"
  autoload :SolrJsonWriter, "cob_index/solr_json_writer"
  autoload :Util, "cob_index/util"

  Array.include CoreExtensions::Array::Transformation

  GENRE_FACET_SPEC = "600v:610v:611v:630v:648v:650v:651v:655av:647v"
end
