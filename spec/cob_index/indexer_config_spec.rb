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

  describe "creator_t" do
    before do
      stub_const("ENV", ENV.to_hash.merge("SOLR_URL" => "foo"))
      indexer.load_config_file("lib/cob_index/indexer_config.rb")
    end

    context "Unwanted corp present" do
      # Note: that "Books24x7, Inc" is excluded via ./lib/list/corporate_names.txt
      let(:record_text) { "
        <record>
          <datafield ind1=' ' ind2=' ' tag='100'>
            <subfield code='b'>FOO</subfield>
          </datafield>
          <datafield ind1=' ' ind2=' ' tag='100'>
            <subfield code='a'>Books24x7, Inc</subfield>
          </datafield>
          <datafield ind1=' ' ind2=' ' tag='110'>
            <subfield code='a'>EBSCO Publishing (Firm)</subfield>
          </datafield>
          <datafield ind1=' ' ind2=' ' tag='700'>
            <subfield code='a'>Ebook Central</subfield>
          </datafield>
        </record>
      " }

      it "removes the unwanted corp" do
        expect(indexer.map_record(record)["creator_txt"]).to eq(["matchbeginswithFOO FOO matchendswithFOO"])
      end
    end
  end

  describe "creator_display" do
    before do
      stub_const("ENV", ENV.to_hash.merge("SOLR_URL" => "foo"))
      indexer.load_config_file("lib/cob_index/indexer_config.rb")
    end

    context "Unwanted corp present" do
      # Note: that "Books24x7, Inc" is excluded via ./lib/list/corporate_names.txt
      let(:record_text) { "
        <record>
          <datafield ind1=' ' ind2=' ' tag='100'>
            <subfield code='b'>FOO</subfield>
          </datafield>
          <datafield ind1=' ' ind2=' ' tag='100'>
            <subfield code='a'>Books24x7, Inc</subfield>
          </datafield>
          <datafield ind1=' ' ind2=' ' tag='110'>
            <subfield code='a'>EBSCO Publishing (Firm)</subfield>
          </datafield>
          <datafield ind1=' ' ind2=' ' tag='700'>
            <subfield code='a'>Ebook Central</subfield>
          </datafield>
        </record>
      " }

      it "removes the unwanted corp" do
        expect(indexer.map_record(record)["creator_display"]).to eq(["FOO"])
      end
    end
  end

  describe "contributor_display" do
    before do
      stub_const("ENV", ENV.to_hash.merge("SOLR_URL" => "foo"))
      indexer.load_config_file("lib/cob_index/indexer_config.rb")
    end

    context "Unwanted corp present" do
      # Note: that "Books24x7, Inc" is excluded via ./lib/list/corporate_names.txt
      let(:record_text) { "
        <record>
          <datafield ind1=' ' ind2=' ' tag='700'>
            <subfield code='b'>FOO</subfield>
          </datafield>
          <datafield ind1=' ' ind2=' ' tag='110'>
            <subfield code='a'>EBSCO Publishing (Firm)</subfield>
          </datafield>
          <datafield ind1=' ' ind2=' ' tag='700'>
            <subfield code='a'>Ebook Central</subfield>
          </datafield>
        </record>
      " }

      it "removes the unwanted corp" do
        expect(indexer.map_record(record)["contributor_display"]).to eq([{ name: "FOO" }.to_json])
      end
    end
  end

  describe "creator_vern_display" do
    before do
      stub_const("ENV", ENV.to_hash.merge("SOLR_URL" => "foo"))
      indexer.load_config_file("lib/cob_index/indexer_config.rb")
    end

    context "Unwanted corp present" do
      # Note: that "Books24x7, Inc" is excluded via ./lib/list/corporate_names.txt
      let(:record_text) { "
        <record>
          <datafield ind1='1' ind2=' ' tag='880'>
            <subfield code='6'>100-01/(2/r</subfield>
            <subfield code='a'>FOO</subfield>
          </datafield>
          <datafield ind1='1' ind2='4' tag='880'>
            <subfield code='6'>110-02/(2/r</subfield>
            <subfield code='a'>Books24x7, Inc</subfield>
          </datafield>
          <datafield ind1=' ' ind2=' ' tag='110'>
            <subfield code='a'>EBSCO Publishing (Firm)</subfield>
          </datafield>
          <datafield ind1=' ' ind2=' ' tag='700'>
            <subfield code='a'>Ebook Central</subfield>
          </datafield>
        </record>
      " }

      it "removes the unwanted corp" do

        expect(indexer.map_record(record)["creator_vern_display"]).to eq(["FOO"])
      end
    end
  end

  describe "contributor_vern_display" do
    before do
      stub_const("ENV", ENV.to_hash.merge("SOLR_URL" => "foo"))
      indexer.load_config_file("lib/cob_index/indexer_config.rb")
    end

    context "Unwanted corp present" do
      # Note: that "Books24x7, Inc" is excluded via ./lib/list/corporate_names.txt
      let(:record_text) { "
        <record>
          <datafield ind1='1' ind2=' ' tag='880'>
            <subfield code='6'>700-01/(2/r</subfield>
            <subfield code='a'>FOO</subfield>
          </datafield>
          <datafield ind1='1' ind2='4' tag='880'>
            <subfield code='6'>700-02/(2/r</subfield>
            <subfield code='a'>Books24x7, Inc</subfield>
          </datafield>
          <datafield ind1=' ' ind2=' ' tag='110'>
            <subfield code='a'>EBSCO Publishing (Firm)</subfield>
          </datafield>
          <datafield ind1=' ' ind2=' ' tag='700'>
            <subfield code='a'>Ebook Central</subfield>
          </datafield>
        </record>
      " }

      it "removes the unwanted corp" do
        expect(indexer.map_record(record)["contributor_vern_display"]).to eq(["FOO"])
      end
    end
  end

  describe "author_sort" do
    before do
      stub_const("ENV", ENV.to_hash.merge("SOLR_URL" => "foo"))
      indexer.load_config_file("lib/cob_index/indexer_config.rb")
    end

    context "Unwanted corp present" do
      # Note: that "Books24x7, Inc" is excluded via ./lib/list/corporate_names.txt
      let(:record_text) { "
        <record>
          <datafield ind1=' ' ind2=' ' tag='100'>
            <subfield code='b'>FOO</subfield>
          </datafield>
          <datafield ind1=' ' ind2=' ' tag='100'>
            <subfield code='a'>Books24x7, Inc</subfield>
          </datafield>
          <datafield ind1=' ' ind2=' ' tag='110'>
            <subfield code='a'>EBSCO Publishing (Firm)</subfield>
          </datafield>
          <datafield ind1=' ' ind2=' ' tag='700'>
            <subfield code='a'>Ebook Central</subfield>
          </datafield>
          <datafield ind1=' ' ind2=' ' tag='110'>
            <subfield code='a'>EBSCO Publishing (Firm)</subfield>
          </datafield>
          <datafield ind1=' ' ind2=' ' tag='700'>
            <subfield code='a'>Ebook Central</subfield>
          </datafield>
        </record>
      " }



      it "removes the unwanted corp" do
        expect(indexer.map_record(record)["author_sort"]).to eq(["FOO"])
      end
    end
  end

  describe "creator_facet field" do
    before do
      stub_const("ENV", ENV.to_hash.merge("SOLR_URL" => "foo"))
      indexer.load_config_file("lib/cob_index/indexer_config.rb")
    end

    context "Unwanted corp present" do
      # Note: that "Books24x7, Inc" is excluded via ./lib/list/corporate_names.txt
      let(:record_text) { "
        <record>
          <datafield ind1=' ' ind2=' ' tag='100'>
            <subfield code='b'>FOO</subfield>
          </datafield>
          <datafield ind1=' ' ind2=' ' tag='100'>
            <subfield code='a'>Books24x7, Inc</subfield>
          </datafield>
          <datafield ind1=' ' ind2=' ' tag='110'>
            <subfield code='a'>EBSCO Publishing (Firm)</subfield>
          </datafield>
          <datafield ind1=' ' ind2=' ' tag='700'>
            <subfield code='a'>Ebook Central</subfield>
          </datafield>
        </record>
      " }

      it "removes the unwanted corp" do
        expect(indexer.map_record(record)["creator_facet"]).to eq(["FOO"])
      end
    end

  end

  describe "translation mappings for record" do
    before do
      stub_const("ENV", ENV.to_hash.merge("SOLR_URL" => "foo"))
      indexer.load_config_file("lib/cob_index/indexer_config.rb")
    end

    let(:record_text) { '
    <record>
      <datafield ind1=" " ind2="0" tag="650">
      <subfield code="a">Noncitizens</subfield>
      <subfield code="z">United States.</subfield>
      </datafield>
      <datafield ind1=" " ind2="0" tag="651">
      </datafield>
      <datafield ind1=" " ind2=" " tag="653">
      <subfield code="a">Illegal aliens</subfield>
      </datafield>
      <datafield ind1=" " ind2=" " tag="653">
      <subfield code="a">United States</subfield>
      </datafield>
      <datafield ind1=" " ind2=" " tag="653">
      <subfield code="a">Social science</subfield>
      </datafield>
    </record>
  ' }

    it "translates unwanted lc headings" do
      expect(indexer.map_record(record)["subject_topic_facet"]).to eq(["Noncitizens — United States", "Undocumented immigrants", "United States", "Social science", "Noncitizens United States"])
    end

  end
end
