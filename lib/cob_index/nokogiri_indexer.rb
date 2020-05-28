# frozen_string_literal: true

require "traject"

module CobIndex
  class NokogiriIndexer < Traject::Indexer::NokogiriIndexer
    def source_record_id_proc
      @source_record_id_proc ||= lambda { |rec| get_id(rec) }
    end

    def extract_id
      proc { |rec, acc| acc << get_id(rec) }
    end

    def extract_status
      proc { |rec, acc|  acc << get_status(rec) }
    end

    def extract_datestamp
      proc { |rec, acc| acc << get_datestamp(rec) }
    end

    def get_status(record)
      do_with_error_log("Failed to get status for record", record) do
        record.at_xpath("//oai:record/oai:header", default_namespaces)["status"]
      end
    end

    def get_id(record)
      do_with_error_log("Failed to get id for record", record) do
        record.at_xpath("//oai:record/oai:header/oai:identifier", default_namespaces)
          .text().scan(/[0-9]+{8}$/).first
      end
    end

    def get_datestamp(record)
      do_with_error_log("Failed to get datastamp record", record) do
        record.at_xpath("//oai:record/oai:header/oai:datestamp", default_namespaces).text()
      end
    end

    def do_with_error_log(message, data = nil)
      begin
        yield if block_given?
      rescue Exception => e
        logger.error(message + ": " + data.to_s)
        raise e
      end
    end
  end
end
