# frozen_string_literal: true

require "rspec"
require "cob_index/macros/marc_format_classifier"
require "cob_index/macros/subject"
require "traject/macros/marc21_semantics"

require "traject/indexer"
require "marc/record"

include CobIndex::Macros::MarcFormats

RSpec.describe CobIndex::Macros::Subject do
  let(:test_class) do
    Class.new(Traject::Indexer) do
      include CobIndex::Macros::Subject
    end
  end

  let(:records) { Traject::MarcReader.new(file, subject.settings).to_a }

  let(:file) { File.new("spec/fixtures/marc_files/#{path}") }

  subject { test_class.new }

  describe "#extract_subjects for subject_display" do

    subject { test_class.new }

    before do
      subject.instance_variable_set(:@fields, []) # <-- reset fields before each test
      subject.instance_eval do
        to_field "subject_display", extract_subjects(
          fields: "600abcdefghklmnopqrstuvxyz:610abcdefghklmnoprstuvxyz:611acdefghjklnpqstuvxyz:630adefghklmnoprstvxyz:647acdgvxyz:648axvyz:650abcdegvxyz:651aegvxyz:653a:654abcevyz:656akvxyz:657avxyz:690abcdegvxyz",
          separator_codes: %w[v x y z])
        settings do
          provide "marc_source.type", "xml"
        end
      end
    end

    context "when a record doesn't have subject topics" do
      let(:path) { "subject_topic_missing.xml" }
      it "does not map a subject_display" do
        expect(subject.map_record(records[0])).to eq({})
      end
    end

    context "when a record has subjects" do
      let(:path) { "subject_display.xml" }
      it "maps data from 6XX fields in expected way" do
        expected = [
          "Kennedy, John F. (John Fitzgerald) 1917-1963 — Pictorial works",
          "Onassis, Jacqueline Kennedy 1929- — Pictorial works",
          "Kennedy, John F. (John Fitzgerald) 1917-1963 — Assassination — Pictorial works",
          "Kennedy family",
          "Presidents — United States — Pictorial works",
          "Presidents' spouses — United States — Pictorial works",
          "Photography — Social aspects — United States — History — 20th century",
          "Mass media — Social aspects — United States — History — 20th century",
          "Popular culture — United States — History — 20th century",
          "Art and popular culture — United States — History — 20th century",
          "United States — Civilization — 1945-"
        ]

        expect(subject.map_record(records[0])).to eq(
          "subject_display" => expected
        )
      end
    end

    context "when translatable subject is present in 650a" do
      let(:record_text) do
        <<-EOT
        <record xmlns="http://www.loc.gov/MARC21/slim">
          <datafield ind1=" " ind2="0" tag="650">
            <subfield code="a">Illegal aliens</subfield>
            <subfield code="z">United States</subfield>
            <subfield code="v">Pictorial works.</subfield>
          </datafield>
          <datafield ind1=" " ind2="0" tag="650">
            <subfield code="a">Presidents' spouses</subfield>
            <subfield code="z">United States</subfield>
            <subfield code="v">Pictorial works.</subfield>
          </datafield>
        </record>
        EOT
      end

      let(:record) { MARC::XMLReader.new(StringIO.new(record_text)).first }

      it "translates subject" do
        expect(subject.map_record(record)["subject_display"]).to eq([
          "Undocumented immigrants — United States — Pictorial works",
          "Presidents' spouses — United States — Pictorial works",
        ])
      end
    end

    context "when translatable subject is present in 650a with punctuation" do

      let(:record_text) do
        <<-EOT
        <record xmlns="http://www.loc.gov/MARC21/slim">
          <datafield ind1=" " ind2="0" tag="650">
            <subfield code="a">Illegal aliens</subfield>
            <subfield code="z">United States</subfield>
            <subfield code="v">Pictorial works.</subfield>
          </datafield>
          <datafield ind1=" " ind2="0" tag="650">
          <subfield code="a">Illegal aliens.</subfield>
            <subfield code="x">Southern States </subfield>
          </datafield>
        </record>
        EOT
      end

      let(:record) { MARC::XMLReader.new(StringIO.new(record_text)).first }

      it "translates subject" do
        expect(subject.map_record(record)["subject_display"]).to eq([
          "Undocumented immigrants — United States — Pictorial works",
          "Undocumented immigrants — Southern States",
        ])
      end
    end

    context "when translatable subject is present in 651a with punctuation" do

      let(:record_text) do
        <<-EOT
        <record xmlns="http://www.loc.gov/MARC21/slim">
          <datafield ind1=" " ind2="0" tag="651">
            <subfield code="a">America, Gulf of.</subfield>
          </datafield>#{'  '}
        </record>
        EOT
      end

      let(:record) { MARC::XMLReader.new(StringIO.new(record_text)).first }

      it "translates subject" do
        expect(subject.map_record(record)["subject_display"]).to eq([
          "Mexico, Gulf of"
        ])
      end
    end

    context "when a non-translatable subject is present in 650a with punctuation" do
      let(:record_text) do
        <<-EOT
        <record xmlns="http://www.loc.gov/MARC21/slim">
          <datafield ind1=" " ind2="0" tag="650">
            <subfield code="a">Test subject.</subfield>
            <subfield code="z">United States</subfield>
          </datafield>
        </record>
      EOT
      end

      let(:record) { MARC::XMLReader.new(StringIO.new(record_text)).first }

      it "strips the punctuation punctuation" do
        expect(subject.map_record(record)["subject_display"]).to eq([
          "Test subject — United States"
        ])
      end
    end

    context "when a translatable subject is in capital letters" do
      let(:record_text) do
        <<-EOT
        <record xmlns="http://www.loc.gov/MARC21/slim">
          <datafield ind1=" " ind2=" " tag="653">
            <subfield code="a">ILLEGAL ALIENS</subfield>
          </datafield>
        </record>
      EOT
      end

      let(:record) { MARC::XMLReader.new(StringIO.new(record_text)).first }

      it "does the translation" do
        expect(subject.map_record(record)["subject_display"]).to eq([
          "Undocumented immigrants"
        ])
      end
    end
  end

  describe "#extract_subjects for subject_topic_facet" do

    before do
      subject.instance_variable_set(:@fields, []) # <-- reset fields before each test
      subject.instance_eval do
        to_field "subject_topic_facet", extract_subjects(
          fields: "600abcdq:610ab:611a:630a:650ax:653a:654ab:647acdg",
          separator_codes: ["x"]
        )
        settings do
          provide "marc_source.type", "xml"
        end
      end
    end

    context "when a record doesn't have subject topics" do
      let(:path) { "subject_topic_missing.xml" }
      it "does not raise an error" do
        expect { subject.map_record(records[0]) }.not_to raise_error
      end

      it "does not map anything to the field" do
        expect(subject.map_record(records[0])).to eq({})
      end
    end

    context "when a record has subject topics" do
      let(:path) { "subject_topic.xml" }
      it "maps data from 650 to the expected field" do
        expect(subject.map_record(records[0])).to eq(
          "subject_topic_facet" => ["The Queen is Dead — Meat is Murder"]
        )
      end

      it "maps data from the 600 to the expected field" do
        expect(subject.map_record(records[1])).to eq(
          # Note that value is flattened
          "subject_topic_facet" => ["Subject Topic moves on to the year 3000"]
          )
      end
    end

    context "record has translatable subject topics. (Including if it ends in period)" do
      let(:record_text) do
        <<-EOT
        <record xmlns="http://www.loc.gov/MARC21/slim">
          <datafield ind1=" " ind2="0" tag="650">
            <subfield code="a">Illegal aliens</subfield>
            <subfield code="z">United States</subfield>
            <subfield code="v">Pictorial works.</subfield>
          </datafield>
          <datafield ind1=" " ind2="0" tag="650">
            <subfield code="a">Alien property.</subfield>
            <subfield code="z">United States</subfield>
            <subfield code="v">Pictorial works.</subfield>
          </datafield>
          <datafield ind1=" " ind2="0" tag="650">
            <subfield code="a">Presidents' spouses</subfield>
            <subfield code="z">United States</subfield>
            <subfield code="v">Pictorial works.</subfield>
          </datafield>
        </record>
      EOT
      end

      let(:record) { MARC::XMLReader.new(StringIO.new(record_text)).first }

      it "translates the subject topics" do
        expect(subject.map_record(record)["subject_topic_facet"]).to eq([
          "Undocumented immigrants",
          "Noncitizen property",
          "Presidents' spouses"
        ])
      end
    end

    context "record has translatable subject topics in subfields a and x" do
      let(:record_text) do
        <<-EOT
        <record xmlns="http://www.loc.gov/MARC21/slim">
          <datafield ind1=" " ind2="0" tag="650">
            <subfield code="a">Illegal aliens</subfield>
            <subfield code="x">Southern States</subfield>
            <subfield code="v">Pictorial works.</subfield>
          </datafield>
        </record>
      EOT
      end

      let(:record) { MARC::XMLReader.new(StringIO.new(record_text)).first }

      it "translates the a and x subfields and only returns the a and x subfields" do
        expect(subject.map_record(record)["subject_topic_facet"]).to eq([
          "Undocumented immigrants — Southern States"
        ])
      end
    end

    context "record has subfield $0" do
      let(:record_text) do
        <<-EOT
        <record xmlns="http://www.loc.gov/MARC21/slim">
          <datafield ind1=" " ind2="0" tag="650">
            <subfield code="a">Mountaineering</subfield>
            <subfield code="0">https://id.loc.gov/authorities/subjects/sh85087816</subfield>
            <subfield code="z">Alaska</subfield>
            <subfield code="z">Denali, Mount.</subfield>
          </datafield>
        </record>
      EOT
      end

      let(:record) { MARC::XMLReader.new(StringIO.new(record_text)).first }

      it "does not display subfield $0 in the facet" do
        expect(subject.map_record(record)["subject_topic_facet"]).to eq([
          "Mountaineering"
        ])
      end
    end
  end

  describe "#extract_subjects for subject_search_facet" do

    before do
      subject.instance_variable_set(:@fields, []) # <-- reset fields before each test
      subject.instance_eval do
        to_field "subject_search_facet", extract_subjects(
          fields: "600abcdq:610ab:611a:630a:650ax:653a:654ab:647acdg",
          separator_codes: %w[v x y z],
          deprecated: true
        )
        settings do
          provide "marc_source.type", "xml"
        end
      end
    end

    context "when a record doesn't have subject topics" do
      let(:path) { "subject_topic_missing.xml" }
      it "does not raise an error" do
        expect { subject.map_record(records[0]) }.not_to raise_error
      end

      it "does not map anything to the field" do
        expect(subject.map_record(records[0])).to eq({})
      end
    end

    context "record contains unwanted LOC terms" do
      let(:record_text) do
        <<-EOT
        <record xmlns="http://www.loc.gov/MARC21/slim">
          <datafield ind1=" " ind2="0" tag="650">
            <subfield code="a">Illegal aliens</subfield>
            <subfield code="x">Southern States</subfield>
            <subfield code="v">Pictorial works.</subfield>
          </datafield>
        </record>
      EOT
      end

      let(:record) { MARC::XMLReader.new(StringIO.new(record_text)).first }

      it "search field returns both deprecated and remediated values" do
        expect(subject.map_record(record)["subject_search_facet"]).to eq([
          "Undocumented immigrants — Southern States"
        ])
      end
    end
  end

  describe "#remediated_marc_geo_facet for subject_region_facet" do

    before do
      subject.instance_variable_set(:@fields, []) # <-- reset fields before each test
      subject.instance_eval do
        to_field "subject_region_facet", remediated_marc_geo_facet(
          options: {}
        )
        settings do
          provide "marc_source.type", "xml"
        end
      end
    end

    context "when a record doesn't have subject regions" do
      let(:path) { "subject_topic_missing.xml" }
      it "does not raise an error" do
        expect { subject.map_record(records[0]) }.not_to raise_error
      end

      it "does not map anything to the field" do
        expect(subject.map_record(records[0])).to eq({})
      end
    end

    context "record contains unwanted LOC terms" do
      let(:record_text) do
        <<-EOT
        <record xmlns="http://www.loc.gov/MARC21/slim">
          <datafield ind1=" " ind2="0" tag="650">
            <subfield code="a">Water</subfield>
            <subfield code="x">Composition</subfield>
            <subfield code="z">America, Gulf of, Watershed.</subfield>
          </datafield>
        </record>
      EOT
      end

      let(:record) { MARC::XMLReader.new(StringIO.new(record_text)).first }

      it "translates the value" do
        expect(subject.map_record(record)["subject_region_facet"]).to eq([
          "Mexico, Gulf of, Watershed"
        ])
      end
    end

    context "record contains unwanted LOC terms with parentheses" do
      let(:record_text) do
        <<-EOT
        <record xmlns="http://www.loc.gov/MARC21/slim">
          <datafield ind1=" " ind2="0" tag="651">
            <subfield code="a">Mount McKinley (Alaska)</subfield>
          </datafield>
        </record>
      EOT
      end

      let(:record) { MARC::XMLReader.new(StringIO.new(record_text)).first }

      it "translates the value" do
        expect(subject.map_record(record)["subject_region_facet"]).to eq([
          "Mount McKinley (Alaska)"
        ])
      end
    end

    context "record has field 043" do
      let(:record_text) do
        <<-EOT
        <record xmlns="http://www.loc.gov/MARC21/slim">
          <datafield ind1=" " ind2=" " tag="043">
            <subfield code="a">n-us-ak</subfield>
          </datafield>
          <datafield ind1=" " ind2="7" tag="651">
            <subfield code="a">Alaska.</subfield>
            <subfield code="2">fast</subfield>
            <subfield code="0">https://id.worldcat.org/fast/1204480</subfield>
          </datafield>
        </record>
      EOT
      end

      let(:record) { MARC::XMLReader.new(StringIO.new(record_text)).first }

      it "does not display the field" do
        expect(subject.map_record(record)["subject_region_facet"]).to eq([
         "Alaska"
        ])
      end
    end
  end
end
