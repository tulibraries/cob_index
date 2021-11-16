# frozen_string_literal: true

require "rspec"
require "traject/indexer"
require "marc/record"

include CobIndex::Macros::MarcFormats
include CobIndex::Macros::Custom

RSpec.describe CobIndex::Macros::Transformations do
  let(:test_class) do
    Class.new(Traject::Indexer)
  end

  let(:record) { MARC::XMLReader.new(StringIO.new(record_text)).first }

  subject { test_class.new }

  describe "#filter_values" do
    before do
      stub_const("ENV", ENV.to_hash.merge("SOLR_DISABLE_UPDATE_DATE_CHECK" => "false"))
      subject.instance_eval do

        extend Traject::Macros::Marc21
        extend CobIndex::Macros::MarcFormats
        extend CobIndex::Macros::Transformations
        to_field "creator_facet", extract_marc("100abcdq:110abcd:111ancdj:700abcdq:710abcd:711ancdj", trim_punctuation: true), filter_values([
          "FOO",
          "Bizz (Buzz)"]);
        settings do
          provide "marc_source.type", "xml"
        end
      end
    end

    context "No creators" do
      let(:record_text) { "
        <record>
        </record>
      "}

      it "does not extract any creator" do
        expect(subject.map_record(record)).to eq({})
      end
    end

    context "Creator but none to filter" do
      let(:record_text) { '
        <record>
          <datafield ind1=" " ind2=" " tag="100">
            <subfield code="a">David Kinzer</subfield>
          </datafield>
        </record>
      '}

      it "extracts the creator" do
        expect(subject.map_record(record)).to eq({
          "creator_facet" => ["David Kinzer"],
        })
      end
    end

    context "Creator and stuff we don't want" do
      let(:record_text) { '
        <record>
          <datafield ind1=" " ind2=" " tag="100">
            <subfield code="a">David Kinzer</subfield>
          </datafield>
          <datafield ind1=" " ind2=" " tag="100">
            <subfield code="a">FOO</subfield>
          </datafield>
        </record>
      '}

      it "extracts the creator" do
        expect(subject.map_record(record)).to eq({
          "creator_facet" => ["David Kinzer"],
        })
      end
    end
  end
end
