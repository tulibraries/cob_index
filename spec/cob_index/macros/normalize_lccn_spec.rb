# frozen_string_literal: true

require "rspec"
require "cob_index/macros/marc_format_classifier"
require "cob_index/macros/custom"
require "traject/macros/marc21_semantics"

require "traject/indexer"
require "marc/record"

include Traject::Macros::MarcFormats
include Traject::Macros::Custom

RSpec.describe Traject::Macros::Custom do
  let(:test_class) do
    Class.new(Traject::Indexer)
  end

  let(:records) { Traject::MarcReader.new(file, subject.settings).to_a }

  let(:file) { File.new("spec/fixtures/marc_files/#{path}") }

  let(:record) { MARC::XMLReader.new(StringIO.new(record_text)).first }

  subject { test_class.new }

  describe "#normalize_lccn" do
    before do
      stub_const("ENV", ENV.to_hash.merge("SOLR_DISABLE_UPDATE_DATE_CHECK" => "false"))
      subject.instance_eval do
        to_field("lccn_display", Traject::Macros::Marc21.extract_marc("010ab", separator: nil), &normalize_lccn)
        settings do
          provide "marc_source.type", "xml"
        end
      end
    end

    context "The simple case" do
      let(:record_text) { '
        <record>
        <datafield ind1=" " ind2=" " tag="010">
        <subfield code="a">87014950</subfield>
        </datafield>
        </record>
      ' }

      it "keeps the number as is" do
        expect(subject.map_record(record)).to eq("lccn_display" => [ "87014950" ])
      end
    end

    context "LCCN includes a # symbol" do
      let(:record_text) { '
        <record>
        <datafield ind1=" " ind2=" " tag="010">
        <subfield code="a">sn#00061556</subfield>
        </datafield>
        </record>
      ' }

      it "removes the # symbol and empty spaces" do
        expect(subject.map_record(record)).to eq("lccn_display" => [ "sn00061556" ])
      end
    end

    context "LCCN includes a / symbol" do
      let(:record_text) { '
        <record>
        <datafield ind1=" " ind2=" " tag="010">
        <subfield code="a">25004346#//r822</subfield>
        </datafield>
        </record>
      ' }

      it "removes the / and all text to the right of it" do
        expect(subject.map_record(record)).to eq("lccn_display" => [ "25004346" ])
      end
    end

  end
end
