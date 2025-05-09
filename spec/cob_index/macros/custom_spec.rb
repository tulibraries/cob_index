# frozen_string_literal: true

require "rspec"
require "cob_index/macros/marc_format_classifier"
require "cob_index/macros/custom"
require "traject/macros/marc21_semantics"

require "traject/indexer"
require "marc/record"

include CobIndex::Macros::MarcFormats
include CobIndex::Macros::Custom

RSpec.describe "custom methods" do

  describe "#four_digit_year(field)" do
    context "when field is nil" do
      it "returns nil" do
        expect(four_digit_year nil).to eq(nil)
      end
    end

    context "when given an empty string" do
      it "returns nil" do
        expect(four_digit_year("")).to eq(nil)
        expect(four_digit_year("\n")).to eq(nil)
        expect(four_digit_year("\n\n")).to eq(nil)
        expect(four_digit_year("      ")).to eq(nil)
      end
    end

    context "when contains Roman Numerals" do
      it "returns nil" do
        expect(four_digit_year "MCCXLV").to eq(nil)
      end
    end

    it 'returns nil for [n.d.],""' do
      expect(four_digit_year '[n.d.],""').to eq(nil)
    end

    it "extracts year from MCCXLV [1745],1745" do
      expect(four_digit_year "MCCXLV [1745],1745").to eq("1745")
    end

    it "extracts the first possible 4 digit numeral" do
      expect(four_digit_year "1918-1966.,1918   ").to eq("1918")
    end

    it "extracts the first possible 4 digit numeral" do
      expect(four_digit_year "18-1966.,1918   ").to eq("1966")
      expect(four_digit_year "c1993.,1993").to eq("1993")
      expect(four_digit_year "©2012,2012").to eq("2012")
    end
  end

  describe "#creator_name_trim_punctuation(name)" do
    context "removes trailing comma, slash" do
      let(:input) { "Richard M. Restak." }
      it "removes trailing period" do
        expect(creator_name_trim_punctuation(input)).to eq("Richard M. Restak")
      end

      let(:input) { "Richard M. Restak," }
      it "removes trailing comma" do
        expect(creator_name_trim_punctuation(input)).to eq("Richard M. Restak")
      end

      let(:input) { "Richard M. Restak/" }
      it "removes trailing slash" do
        expect(creator_name_trim_punctuation(input)).to eq("Richard M. Restak")
      end

      context "keeps period if preceded by characters other than parentheses" do
        let(:input) { "Richard M. Restak" }
        it "retains period after middle initial" do
          expect(creator_name_trim_punctuation(input)).to eq("Richard M. Restak")
        end
      end

      context "removes period following parentheses" do
        let(:input) { "4 Learning (Firm)." }
        it "retains period after middle initial" do
          expect(creator_name_trim_punctuation(input)).to eq("4 Learning (Firm)")
        end
      end
    end
  end
end

RSpec.describe CobIndex::Macros::Custom do
  let(:test_class) do
    Class.new(Traject::Indexer)
  end

  let(:records) { Traject::MarcReader.new(file, subject.settings).to_a }

  let(:file) { File.new("spec/fixtures/marc_files/#{path}") }

  let(:record) { MARC::XMLReader.new(StringIO.new(record_text)).first }

  subject { test_class.new }

  describe "#extract_title_statement" do
    let(:path) { "title_statement_examples.xml" }

    before(:each) do
      subject.instance_eval do
        to_field "title_with_subtitle_display", extract_title_and_subtitle

        settings do
          provide "marc_source.type", "xml"
        end
      end
    end

    context "245 field with subfield a" do
      it "returns title and subtitle" do
        expected = { "title_with_subtitle_display" => ["Die dritte generation" ] }
        expect(subject.map_record(records[0])).to eq(expected)
      end
    end

    context "245 field has a slash" do
      it "does not display slashes" do
        expected = { "title_with_subtitle_display" => ["Yaju no seishun Youth of the beast"] }
        expect(subject.map_record(records[2])).to eq(expected)
      end
    end

    context "title not found with limited selection" do
      it "uses 245A_TO_Z selection" do
        expected = { "title_with_subtitle_display" => ["[video recording]"] }
        expect(subject.map_record(records[3])).to eq(expected)
      end
    end
  end

  describe "#extract_date_added" do
    let(:path) { "date_added_examples.xml" }
    before(:each) do
      subject.instance_eval do
        to_field "date_added_facet", extract_date_added

        settings do
          provide "marc_source.type", "xml"
        end
      end
    end

    context "997a subfield present" do
      it "extracts date_added field in an expected way" do
        expected = { "date_added_facet" => [20210506] }
        expect(subject.map_record(records[0])).to eq(expected)
      end
    end

    context "997a subfield present but shorter than expected" do
      it "extracts padded date_added field" do
        expected = { "date_added_facet" => [20210000] }
        expect(subject.map_record(records[1])).to eq(expected)
      end
    end
  end

  describe "#extract_creator" do
    let(:path) { "creator_examples.xml" }
    before(:each) do
      subject.instance_eval do
        to_field "creator_field", extract_creator

        settings do
          provide "marc_source.type", "xml"
        end
      end
    end

    context "No name available" do
      it "does not extract a creator" do
        expect(subject.map_record(records[0])).to eq({})
      end
    end

    context "Tag 100 only with values in all the subfields" do
      it "extracts creator field in an expected way" do
        expected = { "creator_field" => ["a b c q d|e j m n o p"] }
        expect(subject.map_record(records[1])).to eq(expected)
      end
    end

    context "Tag 110 only with values in all the subfields" do
      it "extracts creator field in an expected way" do
        expected = { "creator_field" => ["a b d c|e l m n o p t"] }
        expect(subject.map_record(records[2])).to eq(expected)
      end
    end

    context "Tag 111 only with values in all the subfields" do
      it "extracts creator field in an expected way" do
        expected = { "creator_field" => ["a n d c j|e l o p t"] }
        expect(subject.map_record(records[3])).to eq(expected)
      end
    end

    context "All three creator fields (100, 110, 111) with all values." do
      it "extracts creator fields in an expected way" do
        expected = { "creator_field" => ["a b c q d|e j m n o p",
                                         "a b d c|e l m n o p t",
                                         "a n d c j|e l o p t"] }
        expect(subject.map_record(records[4])).to eq(expected)
      end
    end
  end

  describe "#extract_creator_vern" do
    let(:path) { "creator_vern_examples.xml" }
    before(:each) do
      subject.instance_eval do
        to_field "creator_vern_display", extract_creator_vern

        settings do
          provide "marc_source.type", "xml"
        end
      end
    end

    context "No name available" do
      it "does not extract a creator" do
        expect(subject.map_record(records[0])).to eq({})
      end
    end

    context "Tag 100 only with values in all the subfields" do
      it "extracts creator field in an expected way" do
        expected = { "creator_vern_display" => ["مطبوعات المجمع؛."] }
        expect(subject.map_record(records[1])).to eq(expected)
      end
    end

    context "Tag 110 only with values in all the subfields" do
      it "extracts creator field in an expected way" do
        expected = { "creator_vern_display" => ["مطبوعات المجمع؛. b c d|e l m n o p t"] }
        expect(subject.map_record(records[2])).to eq(expected)
      end
    end

    context "Tag 111 only with values in all the subfields" do
      it "extracts creator field in an expected way" do
        expected = { "creator_vern_display" => ["مطبوعات المجمع؛. b c d|e l m n o p t"] }
        expect(subject.map_record(records[3])).to eq(expected)
      end
    end

    context "All three creator fields (100, 110, 111) with all values." do
      it "extracts creator fields in an expected way" do
        expected = { "creator_vern_display" => ["مطبوعات المجمع؛. b c d q|e j m n o p", "a b c d|e l m n o p t", "a c d|e j l n o p t"] }
        expect(subject.map_record(records[4])).to eq(expected)
      end
    end
  end

  describe "#extract_contributor" do
    let(:path) { "contributor_examples.xml" }
    before(:each) do
      subject.instance_eval do
        to_field "contributor_display", extract_contributor

        settings do
          provide "marc_source.type", "xml"
        end
      end
    end

    context "Contributor fields display multiple subfields" do
      let(:path) { "creator_multiple_subfields.xml" }

      it "extracts subfields multiple times if multiple subfields are present" do
        expected = { "contributor_display" => [JSON.dump({ "name" => "United States. Department of Agriculture. Economic Research Service" })] }
        expect(subject.map_record(records[0])).to eq(expected)
      end

      it "does not change order of subfields if something is nil" do
        expected = { "contributor_display" => [JSON.dump({ "name" => "Oliveira, Victor J.", "role" => "Test Another plain text field" }),
                                               JSON.dump({ "name" => "Two" }),
                                               JSON.dump({ "name" => "Three", "role" => "Test" })] }
        expect(subject.map_record(records[1])).to eq(expected)
      end
    end

    context "No contributor info available" do
      it "does not extract a contributor" do
        expect(subject.map_record(records[0])).to eq({})
      end
    end

    context "Tag 700 contributor with values in all the subfields" do
      it "extracts contributor field in an expected way" do
        expected = { "contributor_display" => [JSON.dump({ "name" => "a b c d q", "role" => "e j l m n o p r t u" })] }
        expect(subject.map_record(records[1])).to eq(expected)
      end
    end

    context "Tag 710 contributor with values in all the subfields" do
      it "extracts contributor field idisaplayexpected way" do
        expected = { "contributor_display" => [JSON.dump({ "name" => "a b d c", "role" => "e l m n o p t" })] }
        expect(subject.map_record(records[2])).to eq(expected)
      end
    end

    context "Tag 711 contributor with values in all the subfields" do
      it "extracts contributor field in an expected way" do
        expected = { "contributor_display" => [JSON.dump({ "name" => "a n d c j", "role" => "e l o p t" })] }
        expect(subject.map_record(records[3])).to eq(expected)
      end
    end

    context "All three contributor fields (700, 710, 711) with all values." do
      it "extracts contributor fields display expected way" do
        expected = { "contributor_display" => [
                       JSON.dump({ "name" => "a b c q d", "role" => "e j l m n o p r t u" }),
                       JSON.dump({ "name" => "a b d c", "role" => "e l m n o p t" }),
                       JSON.dump({ "name" => "a n d c j", "role" => "e l o p t" })] }
        expect(subject.map_record(records[4])).to eq(expected)
      end
    end

    context "Tag 700 contains i subfield" do
      it "extracts contributor fields display expected way" do
        expected = { "contributor_display" => [JSON.dump({ "relation" => "Container of (work):", "name" => "Baldwin, James, 1924-1987", "role" => "Giovanni's room" })] }
        expect(subject.map_record(records[5])).to eq(expected)
      end
    end
  end

  describe "#extract_uniform_title" do
    let(:path) { "title_statement_examples.xml" }
    before(:each) do
      subject.instance_eval do
        to_field "title_uniform_display", extract_uniform_title

        settings do
          provide "marc_source.type", "xml"
        end
      end
    end

    context "Tag 130" do
      it "extracts uniform title fields display without subfield i expected way" do
        expected = { "title_uniform_display" => [JSON.dump({ "title" => "Japan (Eyewitness travel guides)" })] }
        expect(subject.map_record(records[5])).to eq(expected)
      end
    end
  end

  describe "#extract_additional_title" do
    let(:path) { "title_statement_examples.xml" }
    before(:each) do
      subject.instance_eval do
        to_field "title_addl_display", extract_additional_title
        settings do
          provide "marc_source.type", "xml"
        end
      end
    end

    context "Tag 246 contains i subfield" do
      it "extracts additional title fields display with subfield i expected way" do
        expected = { "title_addl_display" => [JSON.dump({ "relation" => "At head of title:", "title" => "Roof Garden Commission" })] }
        expect(subject.map_record(records[6])).to eq(expected)
      end
    end

    context "Tag 246 without subfield i" do
      it "extracts additional title fields display without subfield i expected way" do
        expected = { "title_addl_display" => [JSON.dump({ "title" => "Lattice detour" })] }
        expect(subject.map_record(records[7])).to eq(expected)
      end
    end

    # BL-1514
    context "Mixed bag including 246a" do
      let(:record_text) { '
        <record xmlns="http://www.loc.gov/MARC21/slim">
          <datafield ind1="0" ind2=" " tag="210">
            <subfield code="a">J. neurosurg.</subfield>
          </datafield>
          <datafield ind1="1" ind2=" " tag="246">
            <subfield code="a">JNS</subfield>
          </datafield>
          <datafield ind1="0" ind2="2" tag="740">
            <subfield code="a">Report on the Traumatic Coma Data Bank.</subfield>
          </datafield>
          <datafield ind1="0" ind2="2" tag="740">
            <subfield code="a">Journal of neurosurgery.</subfield>
            <subfield code="p">Spine.</subfield>
          </datafield>
          <datafield ind1="0" ind2="2" tag="740">
            <subfield code="a">Journal of neurosurgery.</subfield>
            <subfield code="p">Pediatrics.</subfield>
          </datafield>
        </record>
      ' }

      it "extracts additional title fields display without subfield i expected way" do
        expected = { "title_addl_display" => [
          { "title" => "J. neurosurg." },
          { "title" => "JNS" },
          { "title" => "Report on the Traumatic Coma Data Bank." },
          { "title" => "Journal of neurosurgery. Spine." },
          { "title" => "Journal of neurosurgery. Pediatrics." }
        ].map(&:to_json) }
        expect(subject.map_record(record)).to eq(expected)
      end
    end

    context "contains 246i but no title (i.e. other 246 fields)" do
      let(:record_text) { '
        <record xmlns="http://www.loc.gov/MARC21/slim">
          <datafield ind1="1" ind2=" " tag="246">
            <subfield code="i">Foo</subfield>
          </datafield>
        </record>
      ' }
      it "should just skip this because that's a mistake" do
        expect(subject.map_record(record)).to eq({})
      end
    end

    context "Tag 730 contains i subfield" do
      let(:record_text) { '
      <record>
        <datafield ind1="0" ind2="4" tag="730">
          <subfield code="i">Container of (work):</subfield>
          <subfield code="a">Scar of shame (Motion picture)</subfield>
        </datafield>
      </record>
    ' }
      it "extracts uniform title fields display with subfield i expected way" do
        expected = { "title_addl_display" => [JSON.dump({ "relation" => "Container of (work):", "title" => "Scar of shame (Motion picture)" })] }
        expect(subject.map_record(record)).to eq(expected)
      end
    end

  end

  describe "#extract_lang" do
    let(:path) { "extract_lang.xml" }
    before(:each) do
      subject.instance_eval do
        to_field "language_facet", extract_lang

        settings do
          provide "marc_source.type", "xml"
        end
      end
    end

    context "no language(nil)" do
      it "does not error out" do
        expect(subject.map_record(records[0])).to eq({})
      end
    end

    context "041a is 6 chars long" do
      it "only translates first 3 chars" do
        expect(subject.map_record(records[1])).to eq("language_facet" => ["English"])
      end
    end

    context "041d is 6 chars long" do
      it "translates all codes" do
        expect(subject.map_record(records[2])).to eq("language_facet" => ["English", "Spanish"])
      end
    end
  end

  describe "#extract_genre" do
    let(:path) { "genre_facet_examples.xml" }
    before(:each) do
      subject.instance_eval do
        to_field "genre_facet", extract_genre

        settings do
          provide "marc_source.type", "xml"
        end
      end
    end

    context "no genre_facet field present" do
      it "does not error out" do
        expect(subject.map_record(records[0])).to eq({})
      end
    end

    context "String not found in GENRE_STOP_WORDS" do
      it "does map a field to genre_facet" do
        expect(subject.map_record(records[1])).to eq("genre_facet" => ["Drama"])
      end
    end

    context "String found in GENRE_STOP_WORDS" do
      it "does not map a field to genre_facet" do
        expect(subject.map_record(records[2])).to eq({})
      end
    end
  end

  context "electronic resource macros" do
    describe "#extract_availability" do
      before(:each) do
        subject.instance_eval do
          to_field "availability_facet", extract_availability

          settings do
            provide "marc_source.type", "xml"
          end
        end
      end

      context "856 fields with an indicator 1 = 7 are NOT Online" do
        let(:record_text) { '
          <record xmlns="http://www.loc.gov/MARC21/slim">
            <!-- 12. Indicator 7 does not map to Online  -->
            <datafield ind1="7" ind2=" " tag="856">
              <subfield code="u">http://www.access.gpo.gov/congress/commissions/secrecy/index.html</subfield>
              <subfield code="2">http</subfield>
            </datafield>
            <datafield ind1="7" ind2=" " tag="856">
              <subfield code="2">http</subfield>
              <subfield code="z">    Adobe Acrobat reader required to view individual sections of publication    </subfield>
              <subfield code="z">    URL accesses contents page of publication, from which link may be made to the individual sections    </subfield>
            </datafield>
          </record>
        ' }

        it "only indicator1 value 4 are included in Online records" do
          expect(subject.map_record(record)).to_not eq("Online")
        end
      end

      context "856 fields with an indicator 1 = 4 with no subfield u" do
        let(:record_text) { '
          <record>
            <!-- 13. ARCHIVE_IT_LINKS arent included in Online Availability  -->
            <datafield tag="856" ind1="4" ind2="0">
              <subfield code="z">archive</subfield>
            </datafield>
          </record>
        ' }

        it "does not throw error with nil subfield u" do
          expect(subject.map_record(record)).to_not eq("Online")
        end
      end

      context "856 fields with correct indactors are Online" do
        let(:record_text) { '
          <record>
            <!-- 14. Indicator1= 4 and indicator2 = NOT 2 maps to Online  -->
            <datafield tag="856" ind1="4" ind2="0">
              <subfield code="z">Adobe Acrobat reader required to view</subfield>
              <subfield code="u">http://www.access.gpo.gov/congress/commissions/secrecy/index.html</subfield>
            </datafield>
          </record>
        ' }

        it "indicator1 = 4 and indicator2 = NOT 2 maps to Online" do
          expect(subject.map_record(record)).to eq("availability_facet" => ["Online"])
        end
      end

      context "records with a PRT subfield 9 that equals Not Available are NOT Online" do
        let(:record_text) { '
          <record>
          <!-- 16. PRT Subfield 9 == "Not Available"  -->
            <datafield tag="245" ind1="4" ind2="2">
              <subfield code="a">Camp Kennebec Alumni Collection, 1910-2016</subfield>
            </datafield>
            <datafield tag="PRT">
              <subfield code="9">Not Available</subfield>
            </datafield>
          </record>
        ' }

        it "does not map to Online" do
          expect(subject.map_record(record)).to_not eq("availability_facet" => ["Online"])
        end
      end

      context "Archive-it links are NOT Online" do
        let(:record_text) { '
          <record>
            <!-- 9. ARCHIVE_IT_LINKS arent included in Online Availability  -->
            <datafield tag="856" ind1="4" ind2="0">
              <subfield code="z">archive</subfield>
              <subfield code="u">https://archive-it.org/collections/4487</subfield>
            </datafield>
          </record>
        ' }
        it "does not include ARCHIVE_IT_LINKS in Online records" do
          expect(subject.map_record(record)).to_not eq("availability_facet" => ["Online"])
        end
      end

      describe "#extract_availability" do
        let(:path) { "oclc.xml" }

        before(:each) do
          subject.instance_eval do
            to_field "hathi_trust_bib_key_display", lookup_hathi_bib_key
            to_field "availability_facet", extract_availability

            settings do
              provide "marc_source.type", "xml"
            end
          end
        end

        context "record has a matching hathitrust record with allow status" do
          it "adds an online an Online+ETAS availability entry" do
            expect(subject.map_record(records[11])["availability_facet"]).to include("Online")
          end
        end

        context "record has a matching hathitrust record with deny status" do
          it "adds and Online+ETAS but not an Online entry" do
            availability_facet = subject.map_record(records[13])["availability_facet"]
            expect(availability_facet).to include("ETAS")
            expect(availability_facet).not_to include("Online")
          end
        end

        context "record does not have a matching hathitrust record" do
          it "does not add online availability" do
            expect(subject.map_record(records[2])).to eq({})
          end
        end

      end

      describe "#extract_availability(purchase on demand)" do

        before do
          subject.instance_eval do
            to_field("availability_facet", extract_availability)
            settings do
              provide "marc_source.type", "xml"
            end
          end
        end

        context "with purchase order field true" do
          let(:record_text) { "
            <record>
              <datafield ind1='1' ind2=' ' tag='902'>
                <subfield code='a'>EBC-POD</subfield>
                <subfield code='d'>d</subfield>
              </datafield>
              <datafield ind1='1' ind2=' ' tag='100'>
                <subfield code='a'>Foo</subfield>
                <subfield code='q'>q</subfield>
              </datafield>
            </record>
          " }

          it "adds a purchase order availability" do
            expect(subject.map_record(record)["availability_facet"]).to include("Request Rapid Access")
          end

          it "also adds an online availability" do
            expect(subject.map_record(record)["availability_facet"]).to include("Online")
          end
        end

        context "with purchase order field false" do
          let(:record_text) { "
            <record>
            </record>
          " }

          it "does not add purchase order availability" do
            expect(subject.map_record(record)).to eq({})
          end
        end
      end
    end

    describe "#extract_electronic_resource" do

      before(:each) do
        subject.instance_eval do
          to_field "electronic_resource_display", extract_electronic_resource

          settings do
            provide "marc_source.type", "xml"
          end
        end
      end

      context "Neither PRT nor 856 fields are present" do
        let(:record_text) { "<record></record>" }

        it "does not map a field to electronic_resource_display" do
          expect(subject.map_record(record)).to eq({})
        end
      end

      context "Only PRT fields are present" do
        context "single PRT field to electronic_resource_display" do
          let(:record_text) { '
            <record>
              <!-- 1. Only singele PRT field  -->
              <datafield tag="PRT" ind1=" " ind2=" ">
                <subfield code="a">foo</subfield>
                <subfield code="b">https://sandbox01-na.alma.exlibrisgroup.com/view/uresolver/01TULI_INST/openurl?u.ignore_date_coverage=true&amp;rft.mms_id=991026913959703811</subfield>
                <subfield code="f">Access full text online.</subfield>
                <subfield code="d">MAIN</subfield>
                <subfield code="8">53377910870003811</subfield>
              </datafield>
            </record>
          ' }

          it "maps a single PRT field" do
            expect(subject.map_record(record)).to eq(
              "electronic_resource_display" => [ { portfolio_id: "foo", public_note: "Access full text online." }.to_json ]
            )
          end
        end

        context "multiple PRT fields present" do
          let(:record_text) { '
            <record>
              <!-- 2. Only multiple PRT field  -->
              <datafield tag="PRT" ind1=" " ind2=" ">
                <subfield code="a">foo</subfield>
                <subfield code="b">https://sandbox01-na.alma.exlibrisgroup.com/view/uresolver/01TULI_INST/openurl?u.ignore_date_coverage=true&amp;rft.mms_id=991026913959703811</subfield>
                <subfield code="f">Access full text online.</subfield>
                <subfield code="d">MAIN</subfield>
                <subfield code="8">53377910870003811</subfield>
                <subfield code="9">Available</subfield>
              </datafield>
              <datafield tag="PRT" ind1=" " ind2=" ">
                <subfield code="a">bar</subfield>
                <subfield code="b">https://sandbox01-na.alma.exlibrisgroup.com/view/uresolver/01TULI_INST/openurl?u.ignore_date_coverage=true&amp;rft.mms_id=991026913959703811</subfield>
                <subfield code="d">MAIN</subfield>
                <subfield code="k">Authentication Note</subfield>
                <subfield code="8">53377910870003811</subfield>
                <subfield code="9">Not Available</subfield>
              </datafield>
            </record>
          ' }
          it "maps a multiple PRT fields to electronic_resource_display" do
            expect(subject.map_record(record)).to eq(
              "electronic_resource_display" => [
                { portfolio_id: "foo", public_note: "Access full text online.", availability: "Available" }.to_json,
                { portfolio_id: "bar", authentication_note: "Authentication Note", availability: "Not Available" }.to_json,
              ]
            )
          end
        end
      end

      context "Only 856 fields are present" do
        context "single 856 field (ind1 = 4; ind2 = not 2) and no exceptions" do
          let(:record_text) { '
            <record>
              <!-- 3. Only single 856 field (no exception) -->
              <datafield tag="856" ind1="4" ind2="0">
                <subfield code="z">foo</subfield>
                <subfield code="u">http://foobar.com</subfield>
              </datafield>
            </record>
          ' }

          it "maps a single 856 field to electronic_resource_display" do
            expect(subject.map_record(record)).to eq(
              "electronic_resource_display" => [
                { title: "foo", url: "http://foobar.com" }.to_json,
              ]
            )
          end
        end

        context "multiple 856 fields (ind1=4; ind2 not 2) and no exceptions" do
          let(:record_text) { '
            <record>
              <!-- 4. Only multiple 856 fields (no exceptions) -->
              <datafield tag="856" ind1="4" ind2="1">
                <subfield code="z">z</subfield>
                <subfield code="3">3</subfield>
                <subfield code="u">http://foobar.com</subfield>
              </datafield>
              <datafield tag="856" ind1="4" ind2="1">
                <subfield code="y">y</subfield>
                <subfield code="u">http://foobar.com</subfield>
              </datafield>
              <datafield tag="856" ind1="4" ind2="1">
                <subfield code="u">http://foobar.com</subfield>
              </datafield>
            </record>
          ' }

          it "maps multiple 856 fields to electronic_resource_display" do
            expect(subject.map_record(record)).to eq(
              "electronic_resource_display" => [
                { title: "z 3", url: "http://foobar.com" }.to_json,
                { title: "y", url: "http://foobar.com" }.to_json,
                { title: "Link to Resource", url: "http://foobar.com" }.to_json,
              ]
            )
          end
        end

        context "single 856 field (ind1 = 4; ind2 = not 2) with exception" do
          let(:record_text) { '
            <record>
              <!-- 5. Only single 856 field (with exception) -->
              <datafield tag="856" ind1="4" ind2="1">
                <subfield code="z">book review</subfield>
                <subfield code="u">http://foobar.com</subfield>
              </datafield>
            </record>
          ' }

          it "does not map a field to electronic_resource_display" do
            expect(subject.map_record(record)).to eq({})
          end
        end

        context "multiple 856 fields (ind1 = 4; ind2 = not 2) with exceptions" do
          let(:record_text) { '
            <record>
              <!-- 15. Finding aid and more links test record  -->
              <datafield tag="245" ind1="4" ind2="2">
                <subfield code="a">Camp Kennebec Alumni Collection, 1910-2016</subfield>
              </datafield>
              <datafield tag="856" ind1="4" ind2="2">
                <subfield code="3">View a description and list of collection contents in the online finding aid.</subfield>
                <subfield code="u">http://library.temple.edu/collections/scrc/camp-kennebec-alumni</subfield>
              </datafield>
              <datafield tag="856" ind1="4" ind2="0">
                <subfield code="3">View preserved website versions on Archive-It.</subfield>
                <subfield code="u">https://www.archive-it.org/collections/4280</subfield>
              </datafield>
            </record>
          '}

          it "does not map a field to electronic_resource_display" do
            expect(subject.map_record(record)).to eq({})
          end
        end
      end

      context "Both PRT and 856 fields are present" do
        let(:record_text) { '
          <record>
            <!-- 7. PRT field and 856 field (with exception)  -->
            <datafield tag="PRT" ind1=" " ind2=" ">
              <subfield code="a">foo</subfield>
            </datafield>
            <datafield tag="856" ind1="4" ind2="1">
              <subfield code="z">BOOK review</subfield>
              <subfield code="u">http://foobar.com</subfield>
            </datafield>
          </record>
        ' }

        context "856 field has exception" do
          it "only maps the PRT field to electronic_resource_display" do
            expect(subject.map_record(record)).to eq(
              "electronic_resource_display" => [ { portfolio_id: "foo" }.to_json ]
            )
          end
        end
        context "856 has no exception" do
          let(:record_text) { '
            <record>
              <!-- 8. PRT field and 856 field (no exception)  -->
              <datafield tag="PRT" ind1=" " ind2=" ">
                <subfield code="a">foo</subfield>
              </datafield>
              <datafield tag="856" ind1="4" ind2="1">
                <subfield code="z">bar</subfield>
                <subfield code="u">http://foobar.com</subfield>
              </datafield>
            </record>
          ' }

          it "only maps the PRT field to electronic_resource_display" do
            expect(subject.map_record(record)).to eq(
              "electronic_resource_display" => [ { portfolio_id: "foo" }.to_json ]
            )
          end
        end
      end
    end

    describe "#extract_url_more_links" do

      before(:each) do
        subject.instance_eval do
          to_field "url_more_links_display", extract_url_more_links

          settings do
            provide "marc_source.type", "xml"
          end
        end
      end

      context "Neither PRT nor 856 fields are present" do
        let(:record_text) { "<record></record>" }

        it "it does not map a url_more_links_display" do
          expect(subject.map_record(record)).to eq({})
        end
      end

      context "Only a PRT field is present" do
        context "single PRT field" do
          let(:record_text) { '
            <record>
              <!-- 1. Only single PRT field  -->
              <datafield tag="PRT" ind1=" " ind2=" ">
                <subfield code="a">foo</subfield>
                <subfield code="b">https://sandbox01-na.alma.exlibrisgroup.com/view/uresolver/01TULI_INST/openurl?u.ignore_date_coverage=true&amp;rft.mms_id=991026913959703811</subfield>
                <subfield code="f">Access full text online.</subfield>
                <subfield code="d">MAIN</subfield>
                <subfield code="8">53377910870003811</subfield>
              </datafield>
            </record>
          ' }

          it "does not map a field to url_more_links_display" do
            expect(subject.map_record(record)).to eq({})
          end
        end
      end

      context "Only 856 field is present" do
        context "single 856 field (ind1 = 4; ind2 = not 2) with no exceptions" do
          let(:record_text) { '
            <record>
              <!-- 3. Only single 856 field (no exception) -->
              <datafield tag="856" ind1="4" ind2="0">
                <subfield code="z">foo</subfield>
                <subfield code="u">http://foobar.com</subfield>
              </datafield>
            </record>
          ' }

          it "maps a single 856 field to url_more_links_display" do
            expect(subject.map_record(record)).to eq({})
          end
        end

        context "single 856 field (ind1 = 4; ind2 = not 2) with archive-it exception" do
          let(:record_text) { '
            <record>
              <!-- 10. Only single 856 field (with archive-it exception) -->
              <datafield tag="856" ind1="4" ind2="1">
                <subfield code="z">Archive</subfield>
                <subfield code="u">http://archive-it.org/collections/4222</subfield>
              </datafield>
            </record>
            <record>
          ' }

          it "maps a single 856 field to url_more_links_display" do
            expect(subject.map_record(record)).to eq("url_more_links_display" => [ { title: "Archive", url: "http://archive-it.org/collections/4222" }.to_json ])
          end
        end

        context "single 856 field (ind1 = 4; ind2 = not 2) with temple and scrc should not map to more_links" do
          let(:record_text) { '
            <record>
              <!-- 11. Links with temple url and scrc map to url_finding_aid_display -->
              <datafield tag="856" ind1="4" ind2="2">
                <subfield code="z">Finding aid</subfield>
                <subfield code="u">http://library.temple.edu/scrc</subfield>
              </datafield>
            </record>
          ' }

          it "does not include Temple SCRC resources in url_more_links_display" do
            expect(subject.map_record(record)).to eq({})
          end
        end

        context "multiple 856 fields (ind1 = 4; ind2 = not 2) with finding_aids exception" do
          let(:record_text) { '
            <record>
              <!-- Links with temple url and finding_aids map to url_finding_aid_display -->
              <datafield tag="856" ind1="4" ind2="2">
                <subfield code="z">Finding aid</subfield>
                <subfield code="u">http://library.temple.edu/finding_aids</subfield>
              </datafield>
            </record>
          '}

          it "does not include Temple finding_aids resources in url_more_links_display" do
            expect(subject.map_record(record)).to eq({})
          end
        end

        context "856 fields (ind1 = 4; ind2 = not 2) with ArchivesSpace exception" do
          let(:record_text) { '
            <record>
              <!-- Links with scrcarchivesspace url and http map to url_finding_aid_display -->
              <datafield tag="856" ind1="4" ind2="2">
                <subfield code="z">Finding aid</subfield>
                <subfield code="u">http://scrcarchivesspace.temple.edu/repositories/4/resources/796</subfield>
              </datafield>
            </record>
          '}

          it "does not include ArchivesSpace urls in url_more_links_display" do
            expect(subject.map_record(record)).to eq({})
          end
        end

        context "single 856 field (ind1 = 4; ind2 = not 2) with exceptions" do
          let(:record_text) { '
            <record>
              <!-- 5. Only single 856 field (with exception) -->
              <datafield tag="856" ind1="4" ind2="1">
                <subfield code="z">book review</subfield>
                <subfield code="u">http://foobar.com</subfield>
              </datafield>
            </record>
          ' }

          it "maps a single 856 field to url_more_links_display" do
            expect(subject.map_record(record)).to eq(
              "url_more_links_display" => [ { title: "book review", url: "http://foobar.com" }.to_json ],
            )
          end
        end
      end

      context "Both PRT and 856 fields are present" do
        context "856 field has exception" do
          let(:record_text) { '
            <record>
              <!-- 7. PRT field and 856 field (with exception)  -->
              <datafield tag="PRT" ind1=" " ind2=" ">
                <subfield code="a">foo</subfield>
              </datafield>
              <datafield tag="856" ind1="4" ind2="1">
                <subfield code="z">BOOK review</subfield>
                <subfield code="u">http://foobar.com</subfield>
              </datafield>
            </record>
          ' }

          it "does not map either field" do
            expect(subject.map_record(record)).to eq({})
          end
        end
        context "856 has no exception" do
          let(:record_text) { '
            <record>
              <!-- 8. PRT field and 856 field (no exception)  -->
              <datafield tag="PRT" ind1=" " ind2=" ">
                <subfield code="a">foo</subfield>
              </datafield>
              <datafield tag="856" ind1="4" ind2="1">
                <subfield code="z">bar</subfield>
                <subfield code="u">http://foobar.com</subfield>
              </datafield>
            </record>
          ' }

          it "does not map either the PRT or the 856 field (link will be captured by )" do
            expect(subject.map_record(record)).to eq({})
          end
        end
      end
    end

    describe "#extract_url_finding_aid" do

      before(:each) do
        subject.instance_eval do
          to_field "url_finding_aid_display", extract_url_finding_aid

          settings do
            provide "marc_source.type", "xml"
          end
        end
      end

      context "856 field includes temple and scrc with http" do
        let(:record_text) { '
          <record>
            <!-- 11. Links with temple url and scrc map to url_finding_aid_display -->
            <datafield tag="856" ind1="4" ind2="2">
              <subfield code="z">Finding aid</subfield>
              <subfield code="u">http://library.temple.edu/scrc</subfield>
            </datafield>
          </record>
        ' }

        it "it does map to url_finding_aid_display(scrc)" do
          expect(subject.map_record(record)).to eq(
            "url_finding_aid_display" => [ { title: "Finding aid", url: "http://library.temple.edu/scrc" }.to_json ])
        end
      end

      context "856 field includes temple and scrc with https" do
        let(:record_text) { '
          <record>
            <!-- 11. Links with temple url and scrc map to url_finding_aid_display -->
            <datafield tag="856" ind1="4" ind2="2">
              <subfield code="z">Finding aid https</subfield>
              <subfield code="u">https://library.temple.edu/scrc</subfield>
            </datafield>
          </record>
        ' }

        it "it does map to url_finding_aid_display(scrc)" do
          expect(subject.map_record(record)).to eq(
            "url_finding_aid_display" => [ { title: "Finding aid https", url: "https://library.temple.edu/scrc" }.to_json ])
        end
      end

      context "856 fields with finding_aids exception" do
        let(:record_text) { '
          <record>
            <!-- Links with temple url and finding_aids map to url_finding_aid_display -->
            <datafield tag="856" ind1="4" ind2="2">
              <subfield code="z">Finding aid</subfield>
              <subfield code="u">http://library.temple.edu/finding_aids</subfield>
            </datafield>
          </record>
        '}

        it "does map to url_finding_aid_display(finding_aids)" do
          expect(subject.map_record(record)).to eq(
            "url_finding_aid_display" => [ { title: "Finding aid", url: "http://library.temple.edu/finding_aids" }.to_json ])
        end
      end

      context "856 fields with finding-aids exception" do
        let(:record_text) { '
          <record>
            <!-- Links with temple url and finding-aids map to url_finding_aid_display -->
            <datafield tag="856" ind1="4" ind2="2">
              <subfield code="z">Finding aid</subfield>
              <subfield code="u">http://library.temple.edu/finding-aids</subfield>
            </datafield>
          </record>
        '}

        it "does map to url_finding_aid_display(finding-aids)" do
          expect(subject.map_record(record)).to eq(
            "url_finding_aid_display" => [ { title: "Finding aid", url: "http://library.temple.edu/finding-aids" }.to_json ])
        end
      end

      context "856 fields with ArchivesSpace url and http" do
        let(:record_text) { '
          <record>
            <!-- Links with scrcarchivesspace url and http map to url_finding_aid_display -->
            <datafield tag="856" ind1="4" ind2="2">
              <subfield code="z">Finding aid</subfield>
              <subfield code="u">http://scrcarchivesspace.temple.edu/repositories/4/resources/796</subfield>
            </datafield>
          </record>
        '}

        it "does map to url_finding_aid_display" do
          expect(subject.map_record(record)).to eq(
            "url_finding_aid_display" => [ { title: "Finding aid", url: "http://scrcarchivesspace.temple.edu/repositories/4/resources/796" }.to_json ])
        end
      end

      context "856 fields with ArchivesSpace url and https" do
        let(:record_text) { '
          <record>
            <!-- Links with scrcarchivesspace url and https map to url_finding_aid_display -->
            <datafield tag="856" ind1="4" ind2="2">
              <subfield code="z">Finding aid</subfield>
              <subfield code="u">https://scrcarchivesspace.temple.edu/repositories/4/resources/796</subfield>
            </datafield>
          </record>
        '}

        it "does map to url_finding_aid_display" do
          expect(subject.map_record(record)).to eq(
            "url_finding_aid_display" => [ { title: "Finding aid", url: "https://scrcarchivesspace.temple.edu/repositories/4/resources/796" }.to_json ])
        end
      end
    end

    describe "#sort_electronic_resource" do

      before(:each) do
        subject.instance_eval do
          to_field "url_more_links_display", extract_electronic_resource, &sort_electronic_resource!

          settings do
            provide "marc_source.type", "xml"
          end
        end
      end

      context "multiple PRT with same from date but different until date" do
        let(:record_text) { '
          <record>
            <!-- 2. Only multiple PRT field  -->
            <datafield tag="PRT" ind1=" " ind2=" ">
              <subfield code="c">foo</subfield>
              <subfield code="g">Available from 1973 until 2020</subfield>
            </datafield>
            <datafield tag="PRT" ind1=" " ind2=" ">
              <subfield code="c">foo</subfield>
              <subfield code="g">Available from 1973 until 2021</subfield>
            </datafield>
          </record>
        ' }

        it "uses the end date to break the sorting tie" do
          expect(subject.map_record(record)).to eq(
            "url_more_links_display" => [
                { title: "foo", coverage_statement: "Available from 1973 until 2021" }.to_json,
                { title: "foo", coverage_statement: "Available from 1973 until 2020" }.to_json,
            ]
          )
        end
      end
      context "multiple PRT with different from date but same until date" do
        let(:record_text) { '
          <record>
            <!-- 2. Only multiple PRT field  -->
            <datafield tag="PRT" ind1=" " ind2=" ">
              <subfield code="c">foo</subfield>
              <subfield code="g">Available from 1973 until 2020</subfield>
            </datafield>
            <datafield tag="PRT" ind1=" " ind2=" ">
              <subfield code="c">foo</subfield>
              <subfield code="g">Available from 1972 until 2020</subfield>
            </datafield>
          </record>
        ' }

        it "uses the date range size to break the sorting tie" do
          expect(subject.map_record(record)).to eq(
            "url_more_links_display" => [
                { title: "foo", coverage_statement: "Available from 1972 until 2020" }.to_json,
                { title: "foo", coverage_statement: "Available from 1973 until 2020" }.to_json,
            ]
          )
        end
      end

      context "multiple PRT with same date range" do
        let(:record_text) { '
          <record>
            <!-- 2. Only multiple PRT field  -->
            <datafield tag="PRT" ind1=" " ind2=" ">
              <subfield code="c">foo</subfield>
              <subfield code="g">Available from 01/01/1973 until 01/01/2020</subfield>
            </datafield>
            <datafield tag="PRT" ind1=" " ind2=" ">
              <subfield code="c">bar</subfield>
              <subfield code="g">Available from 01/01/1973 until 01/01/2020</subfield>
            </datafield>
          </record>
        ' }

        it "uses the title to break the sorting tie" do
          expect(subject.map_record(record)).to eq(
            "url_more_links_display" => [
                { title: "bar", coverage_statement: "Available from 01/01/1973 until 01/01/2020" }.to_json,
                { title: "foo", coverage_statement: "Available from 01/01/1973 until 01/01/2020" }.to_json,
            ]
          )
        end
      end

      context "An empty set" do
        it "handles an empty accumulator correctly" do
          acc = []
          rec = []
          context = nil
          expect(sort_electronic_resource![acc, rec, context]).to eq([])
        end
      end
    end
  end

  describe "#extract_genre_display" do
    before do
      subject.instance_eval do
        to_field "genre_display", extract_genre_display
        settings do
          provide "marc_source.type", "xml"
        end
      end
    end

    context "when a record doesn't have genres" do
      let(:path) { "genre_display.xml" }
      it "does not map a genre_display" do
        expect(subject.map_record(records[0])).to eq({})
      end
    end

    context "when a record has genres" do
      let(:path) { "genre_display.xml" }
      it "maps data from 655 fields in expected way" do
        expected = [
          "Documentary films",
          "Foreign language films — Chinese"
        ]
        expect(subject.map_record(records[1])).to eq(
          "genre_display" => expected
        )
      end
    end
  end

  describe "#libraries_based_negative_boost" do
    let(:path) { "libraries.xml" }
    before(:each) do
      subject.instance_eval do
        to_field "libraries_based_boost_t", library_based_boost
        settings do
          provide "marc_source.type", "xml"
        end
      end
    end

    context "when Presser is the only library" do
      it "returns negative_boost" do
        expect(subject.map_record(records[0])).to eq("libraries_based_boost_t" => ["no_boost"])
      end
    end

    context "when Presser is not present" do
      it "returns boost" do
        expect(subject.map_record(records[1])).to eq("libraries_based_boost_t" => ["boost"])
      end
    end

    context "when Presser and another library are both present, with presser first" do
      it "returns boost" do
        expect(subject.map_record(records[2])).to eq("libraries_based_boost_t" => ["boost"])
      end
    end

    context "when Presser and another library are both present, with the other library first" do
      it "returns boost" do
        expect(subject.map_record(records[3])).to eq("libraries_based_boost_t" => ["boost"])
      end
    end
  end

  describe "#suppress_items" do
    let(:path) { "lost_missing_technical.xml" }

    before do
      subject.instance_eval do
        to_field "suppress_items_b", suppress_items
        settings do
          provide "marc_source.type", "xml"
        end
      end
    end

    context "when a single item is lost" do
      it "maps lost record" do
        expect(subject.map_record(records[0])).to eq("suppress_items_b" => [true])
      end
    end

    context "when a single item is missing" do
      it "maps missing record" do
        expect(subject.map_record(records[1])).to eq("suppress_items_b" => [true])
      end
    end

    context "when a single item is technical" do
      it "maps technical record" do
        expect(subject.map_record(records[2])).to eq("suppress_items_b" => [true])
      end
    end

    context "when a single item is lost and paid" do
      it "maps lost and paid record" do
        expect(subject.map_record(records[15])).to eq("suppress_items_b" => [true])
      end
    end

    context "when there are multiple items and one of the records is lost" do
      it "does not map to the field" do
        expect(subject.map_record(records[3])).to eq({})
      end
    end

    context "when single holding is in empty library" do
      it "suppresses the file" do
        expect(subject.map_record(records[5])).to eq("suppress_items_b" => [true])
      end
    end

    context "when single holding is intref" do
      it "suppresses the file" do
        expect(subject.map_record(records[16])).to eq("suppress_items_b" => [true])
      end
    end

    context "when single holding is techserv" do
      it "suppresses the file" do
        expect(subject.map_record(records[16])).to eq("suppress_items_b" => [true])
      end
    end

    context "when multiple item fields but single unassinged" do
      it "doesn't suppress this file" do
        expect(subject.map_record(records[6])).to eq({})
      end
    end

    context "when there are no HLD, PRT, or 856['u'] fields" do
      it "does suppress this file" do
        expect(subject.map_record(records[7])).to eq("suppress_items_b" => [true])
      end
    end

    context "when there are no HLD or PRT, but 856['u'] fields are present" do
      it "doesn't suppress this file" do
        expect(subject.map_record(records[8])).to eq({})
      end
    end

    context "when there are no HLD or PRT, and only 856['u'] field includes ind2 '2'" do
      it "does suppress this file" do
        expect(subject.map_record(records[18])).to eq("suppress_items_b" => [true])
      end
    end

    context "when purchase order fields are present with EBC-POD" do
      it "doesn't suppress this file" do
        expect(subject.map_record(records[11])).to eq({})
      end
    end

    context "when purchase order fields are not present" do
      it "does suppress the file" do
        expect(subject.map_record(records[12])).to eq("suppress_items_b" => [true])
      end
    end

    context "when purchase order fields are present without EBC-POD" do
      it "does suppress the file" do
        expect(subject.map_record(records[13])).to eq("suppress_items_b" => [true])
      end
    end

    context "when all fields are lost or missing" do
      it "does suppress the file" do
        expect(subject.map_record(records[9])).to eq("suppress_items_b" => [true])
      end
    end

    context "when only some fields are lost or missing" do
      it "doesn't suppress this file" do
        expect(subject.map_record(records[10])).to eq({})
      end
    end

    context "has a malformed 902 field" do
      it "doesn't raise an error" do
        expect { subject.map_record(records[14]) }.not_to raise_error
      end
    end

    context "when all items are inactive" do
      record_text = <<-EOT
<record>
  <controlfield tag="001">4</controlfield>
  <datafield ind1=" " ind2=" " tag="PRT">
    <subfield code="9">Not Available</subfield>
  </datafield>
  <datafield ind1=" " ind2=" " tag="ITM">
    <subfield code="u">FOO</subfield>
  </datafield>
</record>
EOT

      record = MARC::XMLReader.new(StringIO.new(record_text)).first
      it "does suppress the file" do
        expect(subject.map_record(record)).to eq("suppress_items_b" => [true])
      end
    end

    context "when some items are active" do
      record_text = <<-EOT
<record>
  <controlfield tag="001">4</controlfield>
  <datafield ind1=" " ind2=" " tag="PRT">
    <subfield code="9">Not Available</subfield>
  </datafield>
  <datafield ind1=" " ind2=" " tag="PRT">
    <subfield code="9">Available</subfield>
  </datafield>
  <datafield ind1=" " ind2=" " tag="ITM">
    <subfield code="u">FOO</subfield>
  </datafield>
</record>
EOT

      record = MARC::XMLReader.new(StringIO.new(record_text)).first
      it "does NOT suppress the file" do
        expect(subject.map_record(record)).to eq({})
      end
    end
  end

  describe "full reindex #suppress_items" do
    let(:path) { "lost_missing_technical.xml" }

    before do
      stub_const("ENV", ENV.to_hash.merge("TRAJECT_FULL_REINDEX" => "yes"))
      @writer = Traject::ArrayWriter.new
      @indexer = Traject::Indexer.new(writer: @writer) do
        to_field "suppress_items_b", suppress_items
      end

      subject.instance_eval do
        settings do
          provide "marc_source.type", "xml"
        end
      end
    end

    context "when a single item is lost" do
      it "maps lost record" do
        expect(@indexer.process_record(records[0]).skip?).to eq(true)
      end
    end

    context "when a single item is missing" do
      it "maps  record" do
        expect(@indexer.process_record(records[1]).skip?).to eq(true)
      end
    end

    context "when a single item is technical" do
      it "maps technical record" do
        expect(@indexer.process_record(records[2]).skip?).to eq(true)
      end
    end

    context "when there are multiple items and one of the records is lost" do
      it "does not map to the field" do
        expect(@indexer.process_record(records[3]).skip?).to eq(false)
      end
    end
  end

  describe "#extract_oclc_number" do
    let(:path) { "oclc.xml" }

    before do
      subject.instance_eval do
        to_field "oclc_number_display", extract_oclc_number
        settings do
          provide "marc_source.type", "xml"
        end
      end
    end

    context "when there is no 035 or 979 field" do
      it "does not map record" do
        expect(subject.map_record(records[0])).to eq({})
      end
    end

    context "when 035 field includes OCoLC" do
      it "maps record" do
        expect(subject.map_record(records[1])).to eq("oclc_number_display" => ["1042418854"])
      end
    end

    context "when 979 field includes OCoLC" do
      it "maps record" do
        expect(subject.map_record(records[2])).to eq("oclc_number_display" => ["1042418854"])
      end
    end

    context "when 979 field and 035 field includes OCoLC" do
      it "maps record" do
        expect(subject.map_record(records[3])).to eq("oclc_number_display" => ["1042418854"])
      end
    end

    context "when 979 field includes ocn" do
      it "maps record" do
        expect(subject.map_record(records[4])).to eq("oclc_number_display" => ["986990990"])
      end
    end

    context "when 979 field includes on" do
      it "maps record" do
        expect(subject.map_record(records[5])).to eq("oclc_number_display" => ["1012488209"])
      end
    end

    context "when 979 field includes on inside a string" do
      it "does not map record" do
        expect(subject.map_record(records[8])).to eq({})
      end
    end

    context "when 979 field and 035 field have different OCLC numbers" do
      it "maps record" do
        expect(subject.map_record(records[6])).to eq("oclc_number_display" => ["938995310", "882543310"])
      end
    end

    context "when oclc number has a leading zero" do
      it "removes the leading zero" do
        expect(subject.map_record(records[9])).to eq("oclc_number_display" => ["3885910"])
      end
    end

    context "when 035 field includes subfield 9 with ExL" do
      it "does not map record" do
        expect(subject.map_record(records[7])).to eq({})
      end
    end
  end

  describe "#lookup_oclc_number" do
    let(:path) { "oclc.xml" }

    before do
      subject.instance_eval do
        to_field "hathi_bib_key_display", lookup_hathi_bib_key
        settings do
          provide "marc_source.type", "xml"
        end
      end
    end

    context "when there is no 035 or 979 field" do
      it "does not map record" do
        expect(subject.map_record(records[0])).to eq({})
      end
    end

    context "when the record has an oclc number but it is not in the hathi overlap file" do
      it "does not map record" do
        expect(subject.map_record(records[1])).to eq({})
      end
    end

    context "when the record has an oclc number in the hathi overlap file with status allow" do
      it "maps a record" do
        expect(subject.map_record(records[10])).to eq("hathi_bib_key_display" => [{ bib_key: "102691365", access: "allow" }.to_json])
      end
    end

    context "when the record has an oclc number in the hathi overlap file wth status deny" do
      it "maps record" do
        expect(subject.map_record(records[13])).to eq("hathi_bib_key_display" => [{ bib_key: "102723748", access: "deny" }.to_json])
      end
    end

    context "when the record has multiple oclc number and one is in the hathi overlap file" do
      it "maps record" do
        expect(subject.map_record(records[11])).to eq("hathi_bib_key_display" => [{ bib_key: "102691365", access: "allow" }.to_json])
      end
    end

    context "when the record has multiple oclc number and more than one is in the hathi overlap file" do
      it "maps a record" do
        expect(subject.map_record(records[12])["hathi_bib_key_display"]).to include({ bib_key: "102691365", access: "allow" }.to_json, { bib_key: "102691351", access: "allow" }.to_json)
      end
    end
  end




  describe "#extract_work_access_point" do

    before do
      subject.instance_eval do
        to_field "work_access_point", extract_work_access_point
        settings do
          provide "marc_source.type", "xml"
        end
      end
    end

    context "All fields available" do
      let(:record_text) { "
        <record>
          <datafield ind1='1' ind2=' ' tag='130'>
            <subfield code='a'>a</subfield>
            <subfield code='d'>d</subfield>
          </datafield>
          <datafield ind1='1' ind2=' ' tag='100'>
            <subfield code='a'>a</subfield>
            <subfield code='q'>q</subfield>
          </datafield>
          <datafield ind1='1' ind2=' ' tag='110'>
            <subfield code='a'>a</subfield>
            <subfield code='d'>d</subfield>
          </datafield>
          <datafield ind1='1' ind2=' ' tag='240'>
            <subfield code='a'>a</subfield>
            <subfield code='s'>s</subfield>
          </datafield>
          <datafield ind1='1' ind2=' ' tag='245'>
            <subfield code='a'>a</subfield>
            <subfield code='p'>p</subfield>
          </datafield>
        </record>
      " }

      it "maps only the 130 field" do
        expect(subject.map_record(record)).to eq("work_access_point" => ["a d"])
      end
    end

    context "Only 130 not available" do
      let(:record_text) { "
        <record>
          <datafield ind1='1' ind2=' ' tag='100'>
            <subfield code='a'>a</subfield>
            <subfield code='q'>q</subfield>
          </datafield>
          <datafield ind1='1' ind2=' ' tag='110'>
            <subfield code='a'>a</subfield>
            <subfield code='d'>d</subfield>
          </datafield>
          <datafield ind1='1' ind2=' ' tag='240'>
            <subfield code='a'>a</subfield>
            <subfield code='s'>s</subfield>
          </datafield>
          <datafield ind1='1' ind2=' ' tag='245'>
            <subfield code='a'>a</subfield>
            <subfield code='p'>p</subfield>
          </datafield>
        </record>
      " }

      it "maps 100 . 240" do
        expect(subject.map_record(record)).to eq("work_access_point" => ["a q . a s"])
      end
    end

    context "Only 130 and 100 not available" do
      let(:record_text) { "
        <record>
          <datafield ind1='1' ind2=' ' tag='110'>
            <subfield code='a'>a</subfield>
            <subfield code='d'>d</subfield>
          </datafield>
          <datafield ind1='1' ind2=' ' tag='240'>
            <subfield code='a'>a</subfield>
            <subfield code='s'>s</subfield>
          </datafield>
          <datafield ind1='1' ind2=' ' tag='245'>
            <subfield code='a'>a</subfield>
            <subfield code='p'>p</subfield>
          </datafield>
        </record>
      " }

      it "maps 110 . 240" do
        expect(subject.map_record(record)).to eq("work_access_point" => ["a d . a s"])
      end
    end

    context "Only 130 and 240 not available" do
      let(:record_text) { "
        <record>
          <datafield ind1='1' ind2=' ' tag='100'>
            <subfield code='a'>a</subfield>
            <subfield code='q'>q</subfield>
          </datafield>
          <datafield ind1='1' ind2=' ' tag='110'>
            <subfield code='a'>a</subfield>
            <subfield code='d'>d</subfield>
          </datafield>
          <datafield ind1='1' ind2=' ' tag='245'>
            <subfield code='a'>a</subfield>
            <subfield code='p'>p</subfield>
          </datafield>
        </record>
      " }

      it "maps 100 . 245" do
        expect(subject.map_record(record)).to eq("work_access_point" => ["a q . a p"])
      end
    end

    context "Only 130 and 240 not available" do
      let(:record_text) { "
        <record>
          <datafield ind1='1' ind2=' ' tag='100'>
            <subfield code='a'>a</subfield>
            <subfield code='q'>q</subfield>
          </datafield>
          <datafield ind1='1' ind2=' ' tag='110'>
            <subfield code='a'>a</subfield>
            <subfield code='d'>d</subfield>
          </datafield>
          <datafield ind1='1' ind2=' ' tag='245'>
            <subfield code='a'>a</subfield>
            <subfield code='p'>p</subfield>
          </datafield>
        </record>
      " }

      it "maps 100 . 245" do
        expect(subject.map_record(record)).to eq("work_access_point" => ["a q . a p"])
      end
    end

    context "130, 240 and 100 not available" do
      let(:record_text) { "
        <record>
          <datafield ind1='1' ind2=' ' tag='110'>
            <subfield code='a'>a</subfield>
            <subfield code='d'>d</subfield>
          </datafield>
          <datafield ind1='1' ind2=' ' tag='245'>
            <subfield code='a'>a</subfield>
            <subfield code='p'>p</subfield>
          </datafield>
        </record>
      " }

      it "maps 110 . 245" do
        expect(subject.map_record(record)).to eq("work_access_point" => ["a d . a p"])
      end
    end

    context "130, 240, 100, 110 not available" do
      let(:record_text) { "
        <record>
          <datafield ind1='1' ind2=' ' tag='245'>
            <subfield code='a'>a</subfield>
            <subfield code='p'>p</subfield>
          </datafield>
        </record>
      " }

      it "skips the map" do
        expect(subject.map_record(record)).to eq({})
      end
    end
  end

  describe "#extract_purchase_order" do

    before do
      subject.instance_eval do
        to_field "purchase_order", extract_purchase_order
        settings do
          provide "marc_source.type", "xml"
        end
      end
    end

    context "with mathing 902a field" do
      let(:record_text) { "
        <record>
          <datafield ind1='1' ind2=' ' tag='902'>
            <subfield code='a'>EBC-POD</subfield>
            <subfield code='d'>d</subfield>
          </datafield>
          <datafield ind1='1' ind2=' ' tag='100'>
            <subfield code='a'>Foo</subfield>
            <subfield code='q'>q</subfield>
          </datafield>
        </record>
      " }

      it "maps to true" do
        expect(subject.map_record(record)).to eq("purchase_order" => [true])
      end
    end

    context "without a matching 902a field" do
      let(:record_text) { "
        <record>
          <datafield ind1='1' ind2=' ' tag='902'>
            <subfield code='a'>Buzz</subfield>
            <subfield code='d'>d</subfield>
          </datafield>
          <datafield ind1='1' ind2=' ' tag='100'>
            <subfield code='a'>Foo</subfield>
            <subfield code='q'>q</subfield>
          </datafield>
        </record>
      " }

      it "maps to false" do
        expect(subject.map_record(record)).to eq("purchase_order" => [false])
      end
    end

    context "without a 902a field" do
      let(:record_text) { "
        <record>
        </record>
      " }

      it "maps to false" do
        expect(subject.map_record(record)).to eq("purchase_order" => [false])
      end
    end
  end

  describe "#extract_item_info" do
    let(:path) { "extract_item.xml" }
    before(:each) do
      subject.instance_eval do
        to_field "items_json_display", extract_item_info

        settings do
          provide "marc_source.type", "xml"
        end
      end
    end

    context "when a single ITM field is present" do
      it "produces json output for subfield data" do
        expect(subject.map_record(records[0])).to eq(
          "items_json_display" => [ { item_pid: "23423620820003811" }.to_json ]
        )
      end
    end

    context "when a single HLD field is present" do
      it "produces json output for subfield data" do
        expect(subject.map_record(records[1])).to eq(
          "items_json_display" => [ { holding_id: "22318864040003811",
                                      current_library: "AMBLER",
                                      current_location: "stacks",
                                      call_number: "HJ2051.A595"
                                    }.to_json ]
        )
      end
    end

    context "when both ITM and HLD field is present" do
      it "produces json output for subfield data" do
        expect(subject.map_record(records[2])).to eq(
          "items_json_display" => [ { holding_id: "22318864040003811",
                                      current_library: "AMBLER",
                                      current_location: "stacks",
                                      call_number: "HJ2051.A595"
                                    }.to_json,
                                    { item_pid: "23423620820003811" }.to_json ]
        )
      end
    end
  end

  describe "#extract_update_date" do

    before do
      stub_const("ENV", ENV.to_hash.merge("SOLR_DISABLE_UPDATE_DATE_CHECK" => "false"))
      subject.instance_eval do
        to_field "record_update_date", extract_update_date, default("2002-02-02 02:02:02 UTC")
        settings do
          provide "marc_source.type", "xml"
        end
      end

      ENV["SOLR_DISABLE_UPDATE_DATE_CHECK"] = nil
    end

    context "Latest is ADMa" do
      let(:record_text) { "
        <record>
          <datafield ind1=' ' ind2=' ' tag='ADM'>
            <subfield code='a'>2019-02-02 02:02:02 UTC</subfield>
            <subfield code='b'>2002-02-02 02:02:02 UTC</subfield>
          </datafield>
          <datafield ind1='1' ind2=' ' tag='ITM'>
            <subfield code='q'>2002-02-02 02:02:02 UTC</subfield>
          </datafield>
        </record>
      " }

      it "finds latest date" do
        expect(subject.map_record(record)).to eq("record_update_date" => [ "2019-02-02 02:02:02 UTC" ])
      end
    end

    context "Latest is ITMq" do
      let(:record_text) { "
        <record>
          <datafield ind1=' ' ind2=' ' tag='ADM'>
            <subfield code='a'>2018-02-02 02:02:02 UTC</subfield>
            <subfield code='b'>2002-02-02 02:02:02 UTC</subfield>
          </datafield>
          <datafield ind1='1' ind2=' ' tag='ITM'>
            <subfield code='q'>2019-02-02 02:02:02 UTC</subfield>
          </datafield>
        </record>
      " }

      it "finds the latest date" do
        expect(subject.map_record(record)).to eq("record_update_date" => [ "2019-02-02 02:02:02 UTC" ])
      end
    end

    context "Latest is ITM updated" do
      let(:record_text) { "
        <record>
          <datafield ind1=' ' ind2=' ' tag='ADM'>
            <subfield code='a'>2018-02-02 02:02:02 UTC</subfield>
            <subfield code='b'>2002-02-02 02:02:02 UTC</subfield>
          </datafield>
          <datafield ind1='1' ind2=' ' tag='ITM'>
            <subfield code='q'>2019-02-02 02:02:02 UTC</subfield>
          </datafield>
          <datafield ind1='1' ind2=' ' tag='ITM'>
            <subfield code='q'>2013-02-02 02:02:02 UTC</subfield>
            <subfield code='updated'>2019-02-02 02:02:02 UTC</subfield>
          </datafield>
        </record>
      " }

      it "finds the latest date" do
        expect(subject.map_record(record)).to eq("record_update_date" => [ "2019-02-02 02:02:02 UTC" ])
      end
    end

    context "Latest is HLDupdated" do
      let(:record_text) { "
        <record>
          <datafield ind1=' ' ind2=' ' tag='ADM'>
            <subfield code='a'>2018-02-02 02:02:02 UTC</subfield>
            <subfield code='b'>2002-02-02 02:02:02 UTC</subfield>
          </datafield>
          <datafield ind1='1' ind2=' ' tag='ITM'>
            <subfield code='q'>2017-02-02 02:02:02 UTC</subfield>
          </datafield>
          <datafield ind1='1' ind2=' ' tag='HLD'>
            <subfield code='updated'>2019-02-02 02:02:02 UTC</subfield>
            <subfield code='created'>2013-02-02 02:02:02 UTC</subfield>
          </datafield>
          <datafield ind1='1' ind2=' ' tag='HLD'>
            <subfield code='updated'>2013-02-02 02:02:02 UTC</subfield>
            <subfield code='created'>2014-02-02 02:02:02 UTC</subfield>
          </datafield>
        </record>
      " }

      it "finds the latest date" do
        expect(subject.map_record(record)).to eq("record_update_date" => [ "2019-02-02 02:02:02 UTC" ])
      end
    end

    context "Latest is PRTcreated" do
      let(:record_text) { "
        <record>
          <datafield ind1=' ' ind2=' ' tag='ADM'>
            <subfield code='a'>2018-02-02 02:02:02 UTC</subfield>
            <subfield code='b'>2002-02-02 02:02:02 UTC</subfield>
          </datafield>
          <datafield ind1='1' ind2=' ' tag='ITM'>
            <subfield code='q'>2017-02-02 02:02:02 UTC</subfield>
          </datafield>
          <datafield ind1='1' ind2=' ' tag='HLD'>
            <subfield code='updated'>2014-02-02 02:02:02 UTC</subfield>
            <subfield code='created'>2013-02-02 02:02:02 UTC</subfield>
          </datafield>
          <datafield ind1='1' ind2=' ' tag='HLD'>
            <subfield code='updated'>2013-02-02 02:02:02 UTC</subfield>
            <subfield code='created'>2014-02-02 02:02:02 UTC</subfield>
          </datafield>
          <datafield ind1='1' ind2=' ' tag='PRT'>
            <subfield code='created'>2019-02-02 02:02:02 UTC</subfield>
          </datafield>
        </record>
      " }

      it "finds the latest date" do
        expect(subject.map_record(record)).to eq("record_update_date" => [ "2019-02-02 02:02:02 UTC" ])
      end
    end

    context "Update date is missing" do
      let(:record_text) { "
        <record>
          <datafield ind1=' ' ind2=' ' tag='ADM'>
            <subfield code='a'>2018-02-02 02:02:02 UTC</subfield>
            <subfield code='b'>2002-02-02 02:02:02 UTC</subfield>
          </datafield>
          <datafield ind1='1' ind2=' ' tag='ITM'>
            <subfield code='q'>2017-02-02 02:02:02 UTC</subfield>
          </datafield>
          <datafield ind1='1' ind2=' ' tag='HLD'>
            <subfield code='updated'>2014-02-02 02:02:02 UTC</subfield>
            <subfield code='created'>2013-02-02 02:02:02 UTC</subfield>
          </datafield>
          <datafield ind1='1' ind2=' ' tag='HLD'>
            <subfield code='updated'>2013-02-02 02:02:02 UTC</subfield>
            <subfield code='created'>2014-02-02 02:02:02 UTC</subfield>
          </datafield>
          <datafield ind1='1' ind2=' ' tag='PRT'>
            <subfield code='created'>2019-02-02 02:02:02 UTC</subfield>
          </datafield>
        </record>
      " }

      it "adds an updated date" do
        stub_const("ENV", ENV.to_hash.merge("ALMAOAI_LAST_HARVEST_FROM_DATE" => "2019-03-03 03:03:03"))
        expect(subject.map_record(record)).to eq("record_update_date" => [ Time.now.utc.to_s ])
      end
    end

    context "SOLR_DISABLE_UPDATE_DATE_CHECK ENV is set" do
      let(:record_text) { "
        <record>
        </record>
      " }

      it "uses time now as result" do
        stub_const("ENV", ENV.to_hash.merge("SOLR_DISABLE_UPDATE_DATE_CHECK" => "yes"))
        expect(subject.map_record(record)).to eq("record_update_date" => [ Time.now.utc.to_s ])
      end
    end

    context "Use default date" do
      let(:record_text) { "
        <record>
        </record>
      " }

      it "uses default set" do
        expect(subject.map_record(record)).to eq("record_update_date" => [ "2002-02-02 02:02:02 UTC" ])
      end
    end
  end

  describe "#truncate" do
    context "empty list" do
      it "returns and empty list" do
        expect(truncate()[nil, []]).to eq([])
      end
    end

    context "list with items longer than 300 chars" do
      it "truncates items to 300 chars + ' ...'" do
        a = ["a" * 1000]
        b = truncate()[nil, a].first
        expect(b.length).to eq(304)
      end
    end

    context "pass truncation length" do
      it "truncates items to length chars + ' ...'" do
        a = ["a" * 1000]
        b = truncate(0)[nil, a].first
        expect(b).to eq(" ...")
      end
    end
  end

  describe "#extract_library" do
    let(:path) { "library_facet.xml" }

    before do
      subject.instance_eval do
        to_field "library_facet", extract_library
        settings do
          provide "marc_source.type", "xml"
        end
      end
    end

    context "when one item is missing" do
      it "does not include library with missing item" do
        expect(subject.map_record(records[0])).to eq("library_facet" => ["Japan Campus Library"])
      end
    end
  end

  describe "#extract_location_facet" do
    before do
      subject.instance_eval do
        to_field "location_facet", extract_location_facet
        settings do
          provide "marc_source.type", "xml"
        end
      end
    end

    context "with items that should not be included" do
      let(:record_text) {
        '
        <record xmlns="http://www.loc.gov/MARC21/slim">
          <datafield ind1=" " ind2=" " tag="ITM">
            <subfield code="g">storage</subfield>
            <subfield code="u">EMPTY</subfield>
            <subfield code="f">JAPAN</subfield>
          </datafield>
          <datafield ind1=" " ind2=" " tag="ITM">
            <subfield code="g">storage</subfield>
            <subfield code="u">LOST_LOAN</subfield>
            <subfield code="f">JAPAN</subfield>
          </datafield>
          <datafield ind1=" " ind2=" " tag="ITM">
            <subfield code="g">storage</subfield>
            <subfield code="u">MISSING</subfield>
            <subfield code="f">JAPAN</subfield>
          </datafield>
          <datafield ind1=" " ind2=" " tag="ITM">
            <subfield code="g">storage</subfield>
            <subfield code="u">TECHNICAL</subfield>
            <subfield code="f">JAPAN</subfield>
          </datafield>
          <datafield ind1=" " ind2=" " tag="ITM">
            <subfield code="g">storage</subfield>
            <subfield code="u">UNASSIGNED</subfield>
            <subfield code="f">JAPAN</subfield>
          </datafield>
          <datafield ind1=" " ind2=" " tag="ITM">
            <subfield code="g">storage</subfield>
            <subfield code="f">KIOSK</subfield>
          </datafield>
          <datafield ind1=" " ind2=" " tag="ITM">
            <subfield code="g">storage</subfield>
            <subfield code="f">RES_SHARE</subfield>
          </datafield>
          <datafield ind1=" " ind2=" " tag="ITM">
            <subfield code="f">JAPAN</subfield>
          </datafield>
          <datafield ind1=" " ind2=" " tag="ITM">
            <subfield code="g">stacks</subfield>
            <subfield code="f">JAPAN</subfield>
          </datafield>
        </record>
        '
      }

      it "does not include any item that should not be included" do
        expect(subject.map_record(record)).to eq("location_facet" => ["Japan Campus Library - Stacks"])
      end
    end

    context "any location in ASRS library" do
      let(:record_text) {
        '
        <record xmlns="http://www.loc.gov/MARC21/slim">
          <datafield ind1=" " ind2=" " tag="ITM">
            <subfield code="g">foo</subfield>
            <subfield code="f">ASRS</subfield>
          </datafield>
        </record>
        '
      }

      it "should map locations to BookBot" do
        expect(subject.map_record(record)).to eq("location_facet" => ["Charles Library - BookBot"])
      end

    end
  end

  describe "#build_call_number" do
    let(:record) {
      r = MARC::Record.new
      r.append MARC::DataField.new("050", "", "", ["a", "Z7004.D5"], ["b", "C63 1990"], ["a", "P327"])
      r
    }

    it "ignores superfluous subfield[code='a'] nodes" do
      expect(subject.build_call_number(record, ["050"])).to eq("Z7004.D5 C63 1990")
    end
  end

  describe "#extract_lc_call_number_sort" do

    before do
      subject.instance_eval do
        to_field "lc_call_number_sort", extract_lc_call_number_sort
        settings do
          provide "marc_source.type", "xml"
        end
      end
    end

    # this test is not sufficient by itself. See features/indices_spec.rb
    # in tul_cob for tests that cover Solr document sorting
    context "three records to be sorted by call number" do
      let(:record_text_1) { "
        <record>
          <datafield ind1=' ' ind2=' ' tag='090'>
            <subfield code='a'>Q71.B5</subfield>
          </datafield>
        </record>
      " }
      let(:record_text_2) { "
        <record>
          <datafield ind1=' ' ind2=' ' tag='050'>
            <subfield code='a'>QA71.B5</subfield>
          </datafield>
        </record>
      " }
      let(:record_text_3) { "
        <record>
          <datafield ind1=' ' ind2=' ' tag='090'>
            <subfield code='a'>QA71</subfield>
            <subfield code='b'>.5.B5</subfield>
          </datafield>
          <datafield ind1=' ' ind2=' ' tag='050'>
            <subfield code='a'>AA71</subfield>
            <subfield code='b'>100000000.5.B5</subfield>
          </datafield>
        </record>
      " }

      let(:records) { [
                        MARC::XMLReader.new(StringIO.new(record_text_1)).first,
                        MARC::XMLReader.new(StringIO.new(record_text_2)).first,
                        MARC::XMLReader.new(StringIO.new(record_text_3)).first
                      ]}

      it "converts the call number to a sortable code, using 090 with 050 as a fallback" do
        sort_codes = {}
        records.each_with_index { |record, i|
          sort_codes[i] = subject.map_record(record)["lc_call_number_sort"]
        }
        expect(sort_codes.values.flatten.reverse.sort_by { |code| code.downcase }).to eq sort_codes.values.flatten
      end
    end

    context "records with empty call_number" do
      let(:record_text) { "
        <record>
          <datafield ind1=' ' ind2=' ' tag='090'>
            <subfield code='a'></subfield>
          </datafield>
        </record>
      " }


      it "does not map empty call_numbers" do
        expect(subject.map_record(record)).to eq({})
      end
    end

    context "records with no call_number" do
      let(:record_text) { "
        <record>
          <datafield ind1=' ' ind2=' ' tag='090'>
          </datafield>
        </record>
      " }


      it "does not map empty call_numbers" do
        expect(subject.map_record(record)).to eq({})
      end
    end
  end

  describe "#extract_donor" do
    let(:path) { "donor_541_field.xml" }

    before do
      subject.instance_eval do
        to_field "donor_info_ms", extract_donor
        settings do
          provide "marc_source.type", "xml"
        end
      end
    end

    context "when there is no 541 field" do
      it "does not map record" do
        expect(subject.map_record(records[0])).to eq({})
      end
    end

    context "when 541 field has indicator1=1 AND subfield c is Gift" do
      it "maps record" do
        expect(subject.map_record(records[1])).to eq("donor_info_ms" => ["Donor name"])
      end
    end

    context "when 541 field has indicator1, but not subfield c" do
      it "does not map record" do
        expect(subject.map_record(records[2])).to eq({})
      end
    end

    context "when 541 field has subfield c equals Gift, but not indicator1" do
      it "does not map record" do
        expect(subject.map_record(records[3])).to eq({})
      end
    end

    context "when 541 subfield c has extra punctuation" do
      it "does map record" do
        expect(subject.map_record(records[4])).to eq("donor_info_ms" => ["Donor name"])
      end
    end

    context "when 541 has no subfield a" do
      it "does not map record" do
        expect(subject.map_record(records[5])).to eq({})
      end
    end
  end

  describe "#extract_marc_subfield_limit for title_added_entry_authority_id_ms" do

    let(:path) { "extract_marc_subfield_limit.xml" }

    before do
      subject.instance_eval do
        to_field "title_added_entry_authority_id_ms", extract_marc_subfield_limit("7000:7100:7110", "t", true)

        settings do
          provide "marc_source.type", "xml"
        end
      end
    end

    context "no field" do
      it "does not error out" do
        expect(subject.map_record(records[0])).to eq({})
      end
    end

    context "subtitle limit matches" do
      it "maps field" do
        expect(subject.map_record(records[1])).to eq("title_added_entry_authority_id_ms" => ["https://id.loc.gov/authorities/names/no95021615"])
      end
    end

    context "subtitle limit does not match" do
      it "does not map field" do
        expect(subject.map_record(records[2])).to eq({})
      end
    end

    context "multiple fields with different subfields" do
      it "maps record" do
        expect(subject.map_record(records[3])).to eq("title_added_entry_authority_id_ms" => ["https://id.loc.gov/authorities/names/no95021615", "https://id.loc.gov/authorities/names/no2017008806"])
      end
    end

  end

  describe "#extract_marc_subfield_limit for contributor_authority_record_id_ms" do

    let(:path) { "extract_marc_subfield_limit.xml" }

    before do
      subject.instance_eval do
        to_field "contributor_authority_record_id_ms", extract_marc_subfield_limit("7000:7100:7110", "t", false)

        settings do
          provide "marc_source.type", "xml"
        end
      end
    end

    context "no field" do
      it "does not error out" do
        expect(subject.map_record(records[0])).to eq({})
      end
    end

    context "subtitle limit matches" do
      it "does not map field" do
        expect(subject.map_record(records[1])).to eq({})
      end
    end

    context "subtitle limit does not match" do
      it "maps record" do
        expect(subject.map_record(records[2])).to eq("contributor_authority_record_id_ms" => ["https://id.loc.gov/authorities/names/no2017022085"])
      end
    end

    context "multiple fields with different subfields" do
      it "maps record" do
        expect(subject.map_record(records[3])).to eq("contributor_authority_record_id_ms" => ["https://id.loc.gov/authorities/names/no2017022085"])
      end
    end

  end
end
