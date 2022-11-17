# frozen_string_literal: true

require "rspec"
require "cob_index"
include CobIndex::Macros::Booster


RSpec.describe CobIndex::Macros::Booster do
  let(:test_class) do
    Class.new(Traject::Indexer)
  end

  let(:record) { MARC::XMLReader.new(StringIO.new(record_text)).first }

  subject { test_class.new }


  describe "#add_boost_labels" do

    before :each do
      subject.instance_eval do
        to_field "boost", add_boost_labels
        settings do
          provide "marc_source.type", "xml"
        end
      end
    end

    context "all bad libraries" do
      let(:record_text) { "
        <record>
          <datafield ind1=' ' ind2='0' tag='HLD'>
            <subfield code='b'>PRESSER</subfield>
          </datafield>
        </record>
      " }

      it "adds the inverse_boost_libraries label" do
        expect(subject.map_record(record)).to eq("boost" => ["inverse_boost_libraries"])
      end
    end

    context "all bad libraries multi" do
      let(:record_text) { "
        <record>
          <datafield ind1=' ' ind2='0' tag='HLD'>
            <subfield code='b'>PRESSER</subfield>
          </datafield>
          <datafield ind1=' ' ind2='0' tag='HLD'>
            <subfield code='b'>CLAEDTECH</subfield>
          </datafield>
        </record>
      " }

      it "adds the inverse_boost_libraries label" do
        expect(subject.map_record(record)).to eq("boost" => ["inverse_boost_libraries"])
      end
    end

    context "only some bad libraries multi" do
      let(:record_text) { "
        <record>
          <datafield ind1=' ' ind2='0' tag='HLD'>
            <subfield code='b'>PRESSER</subfield>
          </datafield>
          <datafield ind1=' ' ind2='0' tag='HLD'>
            <subfield code='b'>FOO</subfield>
          </datafield>
        </record>
      " }

      it "adds the inverse_boost_libraries label" do
        expect(subject.map_record(record)).to eq({})
      end
    end

    context "when genre value matches Bookseller" do
      let(:record_text)  { <<-EOT
      <record xmlns="http://www.loc.gov/MARC21/slim">
        <datafield ind1=" " ind2="0" tag="655">
          <subfield code="a">Bookseller</subfield>
        </datafield>
        <datafield ind1=" " ind2="0" tag="655">
        <subfield code="a">Illegal aliens.</subfield>
          <subfield code="x">Southern States </subfield>
        </datafield>
      </record>
      EOT
      }

      it "adds inverse_boost_bookseller label" do
        expect(subject.map_record(record)).to eq("boost" => ["inverse_boost_bookseller"])
      end
    end

    context "when genre value does not match Bookseller" do
      let(:record_text)  { <<-EOT
      <record xmlns="http://www.loc.gov/MARC21/slim">
        <datafield ind1=" " ind2="0" tag="655">
        <subfield code="a">Illegal aliens.</subfield>
          <subfield code="x">Southern States </subfield>
        </datafield>
      </record>
      EOT
      }

      it "does not add inverse_boost_bookseller label" do
        expect(subject.map_record(record)).to eq({})
      end
    end
  end
end
