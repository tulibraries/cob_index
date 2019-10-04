# frozen_string_literal: true

require "cob_index/solr_json_writer"

RSpec.describe CobIndex::SolrJsonWriter do
  let(:fake_http_client) { FakeHttpClient.new }
  let(:strio) { StringIO.new }
  let(:logger) { Logger.new(strio) }
  let(:settings) { {
    "id" => "doc_foo",
    "key" => "value",
    "solr.url" =>  "http://example.com/solr",
    logger: logger,
    "solr_json_writer.http_client" => fake_http_client,
  } }

  let(:subject) { CobIndex::SolrJsonWriter.new(settings) }

  describe "#send_single" do
    context "500 hundred response" do
      let(:fake_http_client) { f = FakeHttpClient.new; f.response_status = 500; f }

      it "raises on non-200-409 http response" do
        expect { subject.send_single(context_with({})) }.to raise_error(RuntimeError)
      end
    end

    context "409 response" do
      let(:fake_http_client) { f = FakeHttpClient.new; f.response_status = 409; f }

      it "does not raise error for 409 http response" do
        expect { subject.send_single(context_with({})) }.not_to raise_error(RuntimeError)
      end

      it "reports 409 errors." do
        subject.send_single(context_with("id" => "foo_bar"))
        expect(strio.string).to match(/WARN -- : Could not add record <output_id:foo_bar>/)
      end
    end


    context "200 response" do
      let(:fake_http_client) { f = FakeHttpClient.new; f.response_status = 200; f }

      it "does not raise error for 200 http response " do
        expect { subject.send_single(context_with({})) }.not_to raise_error(RuntimeError)
      end

    end

    context "Max skipped records exceeded" do
      let(:fake_http_client) { f = FakeHttpClient.new; f.response_status = 3; f }

      let(:settings) { {
        "id" => "doc_foo",
        "key" => "value",
        "solr_writer.max_skipped" => 0,
        "solr.url" =>  "http://example.com/solr",
        "solr_json_writer.http_client" => fake_http_client,
      } }

      it "throws a maxed skipped record exceeded error" do
        expect { subject.send_single(context_with({})) }.to raise_error(Traject::SolrJsonWriter::MaxSkippedRecordsExceeded)
      end
    end
  end


  def context_with(hash)
    Traject::Indexer::Context.new(output_hash: hash)
  end

  class FakeHttpClient
    # Always reply with this status, normally 200, can
    # be reset for testing error conditions.
    attr_accessor :response_status

    def initialize(*args)
      @post_args = []
      @get_args  = []
      @response_status = 200
      @mutex = Monitor.new
    end

    def post(*args)
      @mutex.synchronize do
        @post_args << args
      end

      resp = HTTP::Message.new_response("")
      resp.status = self.response_status

      return resp
    end
  end

end
