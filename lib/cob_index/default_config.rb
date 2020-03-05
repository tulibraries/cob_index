# frozen_string_literal: true

module CobIndex
  module  DefaultConfig
    # Wrapper for our default indexer settings so that we can share them
    # across commands.
    def self.indexer_settings
      solr_url =
        if File.exist? "config/blacklight.yml"
          solr_config = YAML.load_file("config/blacklight.yml")[(ENV["RAILS_ENV"] || "development")]
          ERB.new(solr_config["url"]).result
        else
          ENV["SOLR_URL"]
        end

      proc {
        # type may be "binary", "xml", or "json"
        provide "marc_source.type", "xml"
        # set this to be non-negative if threshold should be enforced
        provide "solr_writer.max_skipped", -1
        provide "solr.url", solr_url
        provide "solr_writer.commit_on_close", false
        provide "writer_class_name", "CobIndex::SolrJsonWriter"

        if ENV["SOLR_AUTH_USER"] && ENV["SOLR_AUTH_PASSWORD"]
          provide "solr_writer.basic_auth_user", ENV["SOLR_AUTH_USER"]
          provide "solr_writer.basic_auth_password", ENV["SOLR_AUTH_PASSWORD"]
        end

      }
    end
  end
end
