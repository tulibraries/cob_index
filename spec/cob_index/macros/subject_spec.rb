# frozen_string_literal: true

require "rspec"
require "cob_index/macros/marc_format_classifier"
require "cob_index/macros/subject"
require "traject/macros/marc21_semantics"

require "traject/indexer"
require "marc/record"

include CobIndex::Macros::MarcFormats
include CobIndex::Macros::Subject

RSpec.describe "custom subject methods" do
  describe "#remediated_topics" do
    let(:record_text) { '
      <record>
        <datafield ind1="0" ind2="4" tag="730">
          <subfield code="i">Container of (work):</subfield>
          <subfield code="a">Scar of shame (Motion picture)</subfield>
        </datafield>
      </record>
  ' }
    context "when field is nil" do
      it "returns nil" do
        # expect(remediated_topics).to be
        expect(subject.map_record(rec)).to eq(record_text)

      end
    end
  end
end
