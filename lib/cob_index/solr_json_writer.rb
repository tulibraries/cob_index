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
        logger.warn "Could not add record #{c.record_inspect} due to version conflict: Solr error response 409."
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

  # Overrides parent::send_batch to optimize Solr version controlled batched
  # updates (if configured to do so).
  #
  # @param [Array<Traject::Indexer::Context>] an array of contexts
  def send_batch(batch)
    if settings["solr_writer.optimize_batch_send"]
      record_update_dates = get_record_update_dates(batch)
      super select_latest_records(batch, record_update_dates)
    else
      super batch
    end
  end

  # Gets record_update_date from Solr given a batch of contexts/records.
  #
  # @param [Array<Traject::Indexer::Context>] an array of contexts
  #
  # @return [Hash] a dictionary where keys are doc ids and values are record_update_date.
  def get_record_update_dates(batch)
    ids = batch.map { |c| c.output_hash["id"] }
      .flatten

    resp = @http_client.get(solr_select_url,
      fq: "id:(#{ids.join(" ")})",
      fl: "id, record_update_date",
      wt: "json",
      rows: batch.count,
      facet: "false",
      spellcheck: "false")

    if resp.status == 200
      JSON.parse(resp.body)["response"]["docs"].reduce({}) do |acc, doc|
        acc.merge(doc["id"] => doc["record_update_date"])
      end
    else
      logger.error "Error in getting solr update date info for batch: #{resp.body}"
      {}
    end
  end

  # Select contexts with dates that are newer than supplied in
  # record_update_dates dictionary.
  #
  # @param [Array<Traject::Indexer::Context>] an array of contexts
  # @param [Hash] a dictionary where keys are record ids and values are record_update_date.
  #
  # @return [Array<Traject::Indexer::Context>] an array of contexts
  def select_latest_records(batch, record_update_dates)
    # We use reduce instead of select in order to be able to do logging.
    batch.reduce([]) do |acc, c|
      context = c.output_hash
      context_update_date = context[:record_update_date] ||
        context["record_update_date"]
      # Output hash values can be in arrays.
      if context_update_date.is_a? Array
        context_update_date = context_update_date.first
      end

      context_update_date = Time.parse(context_update_date) rescue nil

      id = context[:id] || context["id"]
      if id.is_a? Array
        id = id.first
      end

      solr_record_update_date = Time.parse(record_update_dates[id]) rescue nil

      # Something went wrong so default to non optimize
      if context_update_date.nil?
        acc << c

      # Usually true when context is a new record.
      elsif solr_record_update_date.nil?
        acc << c

      # Prevent 409 error by not pushing older context.
      elsif context_update_date <= solr_record_update_date
        logger.info "Filtering out context because it is not newer than the record in the database id:#{id}, solr_date: #{solr_record_update_date}, context_date: #{context_update_date}"

        acc
      else

        acc << c
      end
    end
  end

  def solr_select_url
    @solr_select_url ||=
      if settings["solr.select_url"]
        check_solr_update_url(settings["solr.select_url"])
      else
        self.determine_solr_update_url.gsub(/\/update(\/json)?/, "/select")
      end
  end

  def delete_batch(batch)
    batch.each_slice(@batch_size) do |batch_slice|
      delete(query: delete_batch_query(batch))
    end
  end

  def delete_batch_query(batch)
    "id:(" + batch.flat_map { |c| c.source_record_id }.join(" OR ") + ")"
  end
end
