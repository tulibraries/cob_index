# frozen_string_literal: true

require "yaml"
require "cob_index"
require "cob_index/solr_json_writer"
require "cob_index/default_config"

settings(&CobIndex::DefaultConfig.indexer_settings)

each_record do |record, context|
  status = []
  extract_status[record, status]
  if status != [ "deleted" ]
    context.skip!
  end
end

to_field "id", extract_id
to_field "record_update_date", extract_datestamp
to_field "suppress_items_b", Proc.new { |_, acc| acc << true }
