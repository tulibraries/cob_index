# frozen_string_literal: true

require "cob_index/solr_json_writer"

RSpec.describe CobIndex::SolrJsonWriter do
  let(:subject) { CobIndex::SolrJsonWriter.new(settings) }
  let(:settings) { {
    "id" => "doc_foo",
    "key" => "value",
    "solr.url" =>  "http://example.com/solr",
    logger: logger,
    "solr_json_writer.http_client" => http_client,
  } }
  let(:logger) { Logger.new(strio) }
  let(:strio) { StringIO.new }
  let(:http_client) { double(HTTPClient) }


  let(:resp) {
    r = HTTP::Message.new_response(solr_resp_message)
    r.status = response_status
    r
  }
  let(:solr_resp_message) { "" }
  let(:response_status) { 200 }
  let(:contxt) { context_with(context_hash) }

  before(:each) do
    allow(http_client).to receive(:post) { resp }
    allow(http_client).to receive(:get) { resp }
  end

  describe "#send_single" do
    context "response status is 500" do
      let(:response_status) { 500 }

      it "raises on non-200-409 http response" do
        expect { subject.send_single(context_with({})) }.to raise_error(RuntimeError)
      end
    end

    context "response status is 409" do
      let(:response_status) { 409 }

      it "does not raise error for 409 http response" do
        expect { subject.send_single(context_with({})) }.not_to raise_error(RuntimeError)
      end

      it "reports 409 errors." do
        subject.send_single(context_with("id" => "foo_bar"))
        expect(strio.string).to match(/WARN -- : Could not add record <output_id:foo_bar>/)
      end
    end

    context "response status is 200 (default)" do
      it "does not raise error for 200 http response " do
        expect { subject.send_single(context_with({})) }.not_to raise_error(RuntimeError)
      end
    end

    context "Max skipped records exceeded" do
      let(:response_status) { 500 }
      let(:settings) { {
        "id" => "doc_foo",
        "key" => "value",
        "solr_writer.max_skipped" => 0,
        "solr.url" =>  "http://example.com/solr",
        "solr_json_writer.http_client" => http_client,
      } }

      it "throws a maxed skipped record exceeded error" do
        expect { subject.send_single(context_with({})) }.to raise_error(Traject::SolrJsonWriter::MaxSkippedRecordsExceeded)
      end
    end
  end

  describe "#send_batch" do
    let(:batch) { [contxt] }
    let(:context_hash) { { id: "foo" } }

    before(:each) do
      allow(subject).to receive(:get_record_update_dates)
      allow(subject).to receive(:select_latest_records) { batch }
      subject.send_batch(batch)
    end

    context "solr_writer.optimize_batch_send is true" do
      let(:settings) { {
        "solr.url" => "http://example.com:8983/solr/collection",
        "solr_json_writer.http_client" => http_client,
        "solr_writer.optimize_batch_send" => true,
      } }

      it "calls optimizing methods" do
        expect(subject).to have_received(:get_record_update_dates)
        expect(subject).to have_received(:select_latest_records)
      end
    end

    context "solr_writer.optimize_batch_send is not true" do
      let(:settings) { {
        "solr.url" => "http://example.com:8983/solr/collection",
        "solr_json_writer.http_client" => http_client,
      } }

      it "does not call optimizing methods" do
        expect(subject).not_to have_received(:get_record_update_dates)
        expect(subject).not_to have_received(:select_latest_records)
      end
    end
  end

  describe "#get_record_update_dates" do
    let(:context1) {
      context_with(id: "foo", record_update_date: "2019-12-01T00:00:00")
    }
    let(:context2) {
      context_with(id: "bar", record_update_date: "2019-12-01T00:00:01")
    }
    let(:batch) { [context1, context2] }

    context "solr responsds with non 200 status code" do
      let(:response_status) { 500 }

      it "returns an empty hash" do
        expect(subject.get_record_update_dates(batch)).to eq({})
      end

      it "logs that an error happened" do
        subject.get_record_update_dates(batch)
        expect(strio.string).to match(/ERROR -- : Error in getting solr update date info for batch/)
      end
    end

    context "solr responsds with correct data " do
      let(:solr_resp_message) { {
        response: { docs: [
          { id: "foo", record_update_date: "2019-12-01T00:00:00" },
          { id: "bar", record_update_date: "2019-12-01T00:00:00" },
        ] }
      }.to_json }

      it "returns hash of record ids matched to record update dates" do
        update_dates = {
          "foo" => "2019-12-01T00:00:00",
          "bar" => "2019-12-01T00:00:00",
        }
        expect(subject.get_record_update_dates(batch)).to eq(update_dates)
      end
    end
  end

  describe "#select_latest_records" do
    let(:batch) { [contxt] }
    let(:solr_resp_message) { { response: { docs: [ record ] } }.to_json }

    context "context has no record_update_date field" do
      let(:context_hash) { { id: "foo" } }
      let(:update_dates) { { "foo" => "2019-12-01T00:00:00" } }

      it "does not filter out context" do
        expect(subject.select_latest_records(batch, update_dates)).to eq(batch)
      end
    end

    context "context has malformed record_update_date field" do
      let(:context_hash) { { id: "foo", record_update_date: "bar" } }
      let(:update_dates) { { "foo" => "2019-12-01T00:00:00" } }

      it "does not filter out context" do
        expect(subject.select_latest_records(batch, update_dates)).to eq(batch)
      end
    end

    context "record has no record_update_date field" do
      let(:context_hash) { { id: "foo", record_update_date: "2019-12-01T00:00:00" } }
      let(:update_dates) { { "foo" => nil } }

      it "does not filter out context" do
        expect(subject.select_latest_records(batch, update_dates)).to eq(batch)
      end
    end

    context "record has malformed record_update_date field" do
      let(:context_hash) { { id: "foo", record_update_date: "2019-12-01T00:00:00" } }
      let(:update_dates) { { "foo" => "bar" } }

      it "does not filter out context" do
        expect(subject.select_latest_records(batch, update_dates)).to eq(batch)
      end
    end

    context "context's record_update_date is latest" do
      let(:context_hash) { { id: "foo", record_update_date: "2019-12-01T00:00:01" } }
      let(:update_dates) { { "foo" => "2019-12-01T00:00:00" } }

      it "does not filter out context" do
        expect(subject.select_latest_records(batch, update_dates)).to eq(batch)
      end
    end

    context "record's record_update_date is latest" do
      let(:context_hash) { { id: "foo", record_update_date: "2019-12-01Z00:00:00" } }
      let(:update_dates) { { "foo" => "2019-12-01Z00:00:01" } }

      it "does filter out context" do
        expect(subject.select_latest_records(batch, update_dates)).to eq([])
      end

      it "should log that it's filtering out the context" do
        subject.select_latest_records(batch, update_dates)
        expect(strio.string).to match(/INFO -- : Filtering out context because it is not newer than the record in the database id:foo/)
      end
    end

    context "record and context have the same update date" do
      let(:context_hash) { { id: "foo", record_update_date: "2019-12-01Z00:00:00" } }
      let(:update_dates) { { "foo" => "2019-12-01Z00:00:00" } }

      it "does filter out context" do
        expect(subject.select_latest_records(batch, update_dates)).to eq([])
      end

      it "should log that it's filtering out the context" do
        subject.select_latest_records(batch, update_dates)
        expect(strio.string).to match(/INFO -- : Filtering out context because it is not newer than the record in the database id:foo/)
      end
    end

    context "record's record_update_date is latest and keys are strings" do
      let(:context_hash) { { "id" => "foo", "record_update_date" => "2019-12-01Z00:00:00" } }
      let(:update_dates) { { "foo" => "2019-12-01Z00:00:01" } }

      it "does filter out context (with indifferent access)" do
        expect(subject.select_latest_records(batch, update_dates)).to eq([])
      end
    end
  end

  describe "solr_select_url" do
    context "solr.select_url setting is defined with good URL"  do
      let(:settings) { {
        "solr.url" =>  "http://example.com/solr/collection",
        "solr.select_url" => "http://example.com/solr/collection/myselect"
      } }

      it "uses the configured solr.select_url" do
        expect(subject.solr_select_url).to eq("http://example.com/solr/collection/myselect")
      end
    end

    context "solr.select_url setting is defined with bad URL"  do
      let(:settings) { {
        "solr.url" =>  "http://example.com/solr",
        "solr.select_url" => "foobar"
      } }

      it "throws an error" do
        expect { subject.solr_select_url }.to raise_error(ArgumentError)
      end
    end

    context "solr.select_url not defined"  do
      let(:settings) { {
        "solr.url" =>  "http://example.com/solr/collection",
      } }

      it "derives the select_url" do
        expect(subject.solr_select_url).to eq("http://example.com/solr/collection/select/json")
      end
    end
  end

  def context_with(hash)
    Traject::Indexer::Context.new(output_hash: hash)
  end
end
