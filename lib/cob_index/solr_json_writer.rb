# frozen_string_literal: true

class CobIndex::SolrJsonWriter < Traject::SolrJsonWriter
  VALID_RESPONSE_CODES = [200, 409]

  # Overries parent::send_single in order to to not throw error on 409.
  # Send a single context to Solr, logging an error if need be
  # @param [Traject::Indexer::Context] c The context whose document you want to send
  def send_single(c)
    logger.debug("#{self.class.name}: sending single record to Solr: #{c.output_hash}")

    json_package = JSON.generate([c.output_hash])
    begin
      post_url = solr_update_url_with_query(@solr_update_args)
      resp = @http_client.post post_url, json_package, "Content-type" => "application/json"

      unless VALID_RESPONSE_CODES.include?(resp.status)
        raise BadHttpResponse.new("Unexpected HTTP response status #{resp.status} from POST #{post_url}", resp)
      end

      if resp.status == 409
        # log 409s responses even if ignoring them.
        logger.warn "Could not add record #{c.record_inspect} do to version conflict: Solr error response 409."
      end

      # Catch Timeouts and network errors -- as well as non-200 http responses --
      # as skipped records, but otherwise allow unexpected errors to propagate up.
    rescue *skippable_exceptions => exception
      msg = if exception.kind_of?(BadHttpResponse)
        "Solr error response: #{exception.response.status}: #{exception.response.body}"
      else
        Traject::Util.exception_to_log_message(exception)
      end

      logger.error "Could not add record #{c.record_inspect}: #{msg}"
      logger.debug("\t" + exception.backtrace.join("\n\t")) if exception
      logger.debug(c.source_record.to_s) if c.source_record

      @skipped_record_incrementer.increment
      if @max_skipped && (skipped_record_count > @max_skipped)
        # re-raising in rescue means the last encountered error will be available as #cause
        # on raised exception, a feature in ruby 2.1+.
        raise MaxSkippedRecordsExceeded.new("#{self.class.name}: Exceeded maximum number of skipped records (#{@max_skipped}): aborting: #{exception.message}")
      end
    end
  end
end
