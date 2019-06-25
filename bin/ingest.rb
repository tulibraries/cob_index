#!/usr/bin/env ruby
# frozen_string_literal: true

require "bundler/setup"
require "traject"

indexer = Traject::Indexer::MarcIndexer.new("solr_writer.commit_on_close": true)
indexer.load_config_file("./lib/cob_index/indexer_config.rb")
indexer.process(StringIO.new(open(ARGV[0]).read))
