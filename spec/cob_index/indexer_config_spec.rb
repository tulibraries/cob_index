# frozen_string_literal: true

RSpec.describe "Traject configuration" do
  let(:indexer) { Traject::Indexer::MarcIndexer.new("solr_writer.commit_on_close": true) }
  let(:settings) {
    indexer.load_config_file("lib/cob_index/indexer_config.rb")
    indexer.settings
  }

  context "neither SOLR_AUTH_USER, nor SOLR_AUTH_PASSWORD env variables are set" do
    before do
      ENV["SOLR_URL"] = "http://example.com:8090"
    end

    it "does not set solr_writer.basic_auth_user" do
      expect(settings["solr_writer.basic_auth_user"]).to be_nil
    end

    it "does not set solr_writer.basic_auth_password" do
      expect(settings["solr_writer.basic_auth_password"]).to be_nil
    end
  end

  context "only SOLR_AUTH_USER env variable is set" do
    before do
      ENV["SOLR_AUTH_USER"] = "foo"
    end

    after do
      ENV.delete("SOLR_AUTH_USER")
    end

    it "does not set solr_writer.basic_auth_user" do
      expect(settings["solr_writer.basic_auth_user"]).to be_nil
    end

    it "does not set solr_writer.basic_auth_password" do
      expect(settings["solr_writer.basic_auth_password"]).to be_nil
    end
  end

  context "only SOLR_AUTH_PASSWORD env variable is set" do
    before do
      ENV["SOLR_AUTH_PASSWORD"] = "bar"
    end

    after do
      ENV.delete("SOLR_AUTH_PASSWORD")
    end

    it "does not set solr_writer.basic_auth_user" do
      expect(settings["solr_writer.basic_auth_user"]).to be_nil
    end

    it "does not set solr_writer.basic_auth_password" do
      expect(settings["solr_writer.basic_auth_password"]).to be_nil
    end
  end

  context "both SOLR_AUTH_USER, and  SOLR_AUTH_PASSWORD env variables are set" do
    before do
      ENV["SOLR_AUTH_USER"] = "foo"
      ENV["SOLR_AUTH_PASSWORD"] = "bar"
    end

    after do
      ENV.delete("SOLR_AUTH_USER")
      ENV.delete("SOLR_AUTH_PASSWORD")
    end

    it "does not set solr_writer.basic_auth_user" do
      expect(settings["solr_writer.basic_auth_user"]).to eq("foo")
    end

    it "does not set solr_writer.basic_auth_password" do
      expect(settings["solr_writer.basic_auth_password"]).to eq("bar")
    end
  end
end
