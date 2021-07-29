# frozen_string_literal: true

RSpec.describe "Traject configuration" do
  let(:indexer) { Traject::Indexer::MarcIndexer.new("solr_writer.commit_on_close": true) }
  let(:settings) {
    indexer.load_config_file("lib/cob_index/indexer_config.rb")
    indexer.settings
  }
  let(:record) { MARC::XMLReader.new(StringIO.new(record_text)).first }

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

  describe "lc_inner_facet field" do
    before do
      stub_const("ENV", ENV.to_hash.merge("SOLR_URL" => "foo"))
      indexer.load_config_file("lib/cob_index/indexer_config.rb")
    end

    context "050a subfield present" do
      let(:record_text) { "
        <record>
          <datafield ind1=' ' ind2=' ' tag='050'>
            <subfield code='a'>QA71</subfield>
            <subfield code='b'>.5.B5</subfield>
          </datafield>
        </record>
      " }

      it "extracts 50a field" do
        expect(indexer.map_record(record)["lc_inner_facet"]).to eq(["QA - Mathematics"])
      end
    end

    context "050a and 090 subfields present" do
      let(:record_text) { "
        <record>
          <datafield ind1=' ' ind2=' ' tag='050'>
            <subfield code='a'>KF71</subfield>
            <subfield code='b'>.5.B5</subfield>
          </datafield>
          <datafield ind1=' ' ind2=' ' tag='090'>
            <subfield code='a'>QA71</subfield>
            <subfield code='b'>.5.B5</subfield>
          </datafield>
        </record>
      " }

      it "extracts 90a field" do
        expect(indexer.map_record(record)["lc_inner_facet"]).to eq(["QA - Mathematics"])
      end
    end
  end

  describe "lc_outer_facet field" do
    before do
      stub_const("ENV", ENV.to_hash.merge("SOLR_URL" => "foo"))
      indexer.load_config_file("lib/cob_index/indexer_config.rb")
    end

    context "050a subfield present" do
      let(:record_text) { "
        <record>
          <datafield ind1=' ' ind2=' ' tag='050'>
            <subfield code='a'>QA71</subfield>
            <subfield code='b'>.5.B5</subfield>
          </datafield>
        </record>
      " }

      it "extracts 50a field" do
        expect(indexer.map_record(record)["lc_outer_facet"]).to eq(["Q - Science"])
      end
    end
  end

  describe "donor_info_display" do
    before do
      stub_const("ENV", ENV.to_hash.merge("SOLR_URL" => "foo"))
      indexer.load_config_file("lib/cob_index/indexer_config.rb")
    end

    context "mmsid mapped to donor" do
      let(:record_text) { '
        <record>
          <controlfield tag="001">991037327694403811</controlfield>
        </record>
      ' }

      it "adds a donor" do
        expect(indexer.map_record(record)["donor_info_display"]).to eq(["Baisch, Wister S. and Harriet H."])
      end
    end


    context "mmsid not mapped to donor" do
      let(:record_text) { '
        <record>
          <controlfield tag="001">foo</controlfield>
        </record>
      ' }

      it "adds a donor" do
        expect(indexer.map_record(record)["donor_info_display"]).to eq(nil)
      end
    end
  end
end
