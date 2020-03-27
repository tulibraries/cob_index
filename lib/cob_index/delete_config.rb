# frozen_string_literal: true

require "yaml"
require "cob_index"
require "cob_index/solr_json_writer"
require "cob_index/default_config"
require "concurrent"

settings(&CobIndex::DefaultConfig.indexer_settings)


deletes = Concurrent::Set.new

to_field "id", extract_id
to_field "status", extract_status
to_field "record_update_date", extract_datestamp

each_record do |record, context|
  context.skip!

  if context.output_hash["status"] == [ "deleted" ]
    logger.info "Adding record id:#{context.source_record_id} to record delete batching processs."
    deletes <<  context
  end
end

after_processing do
  writer.delete_batch(deletes)
end
