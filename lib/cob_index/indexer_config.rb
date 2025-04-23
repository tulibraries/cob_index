# frozen_string_literal: true

require "yaml"
require "cob_index"
require "cob_index/macros/subject"

# To have access to various built-in logic
# for pulling things out of MARC21, like `marc_languages`
require "traject/macros/marc21_semantics"
extend  Traject::Macros::Marc21Semantics

# Add the Marc21 overrides.
Traject::Macros::Marc21.include(CobIndex::Macros::Marc21)

extend CobIndex::Macros::MarcFormats

# Include custom traject macros
extend CobIndex::Macros::Custom
extend CobIndex::Macros::Subject

# Include boosting macros
extend CobIndex::Macros::Booster

extend CobIndex::Macros::Wrapper

CORPORATE_NAMES = CobIndex::Util.load_list_file("corporate_names")

settings(&CobIndex::DefaultConfig.indexer_settings)

each_record do |record, context|
  if record.fields("245").any? { |f| f["a"].to_s.downcase.include? "host bibliographic record for boundwith item barcode" }
    context.skip!("Skipping Boundwith host record")
  end
end

to_field "id", extract_marc("001", first: true)
to_field "marc_display_raw", get_xml
to_field("text", extract_all_marc_values, &to_single_string)
to_field "language_facet", extract_lang("008[35-37]:041a:041d:041e:041g:041j")
to_field "language_display", extract_lang("008[35-37]:041a:041d:041e:041g:041j")
to_field("format", marc_formats, &normalize_format)

#LC call number
to_field "lc_call_number_display", extract_lc_call_number_display
to_field "lc_outer_facet", extract_lc_outer_facet
to_field "lc_inner_facet", extract_lc_inner_facet

# Title fields
# Used on the full record page
to_field "title_statement_display", extract_title_statement
to_field "title_with_subtitle_display", extract_title_and_subtitle
to_field "responsibility_display", extract_marc("245c")

# Used in the catalog search results display
to_field "title_truncated_display", extract_title_statement, &truncate(300)
to_field "title_with_subtitle_truncated_display", extract_title_and_subtitle, &truncate(300)
to_field "responsibility_truncated_display", extract_marc("245c"), &truncate(300)
to_field "title_statement_vern_display", extract_marc("245abcfgknps", alternate_script: :only)
to_field "title_with_subtitle_vern_display", extract_marc("245abfgknps", alternate_script: :only)
to_field "responsibility_vern_display", extract_marc("245c", alternate_script: :only)
to_field "title_uniform_display", extract_uniform_title
to_field "title_uniform_vern_display", extract_marc("130adfklmnoprs:240adfklmnoprs", alternate_script: :only)
to_field "title_addl_display", extract_additional_title
to_field "title_addl_vern_display", extract_marc("210ab:246abfgnp:247abcdefgnp:730ail:740anp", alternate_script: :only)
to_field "title_txt", extract_marc("245a"), wrap_begin_end
to_field "subtitle_txt", extract_marc("245b"), wrap_begin_end
to_field "title_statement_txt", extract_marc("245abfgknps"), wrap_begin_end
to_field "title_uniform_txt", extract_marc("130adfklmnoprs:240adfklmnoprs:730abcdefgklmnopqrst"), wrap_begin_end
to_field "title_uniform_authority_record_id_ms", extract_marc("1300:2400:7300")

to_field "work_access_point", extract_work_access_point

A_TO_U = ("a".."u").to_a.join("")
to_field "title_addl_txt",
  extract_marc(%W{
    210ab
    222ab
    242abnp
    243abcdefgklmnopqrs
    246abcdefgnp
    247abcdefgnp
    740anp
               }.join(":"))
to_field "title_added_entry_txt", extract_marc(%W{
  700gklmnoprst
  710fgklmnopqrst
  711fgklnpst

                                             }.join(":")), wrap_begin_end

to_field "title_added_entry_authority_id_ms", extract_marc_subfield_limit("7000:7100:7110", "t", true)
to_field "title_added_entry_real_world_object_uri_ms", extract_marc_subfield_limit("7001:7101:7111", "t", true)

to_field "title_sort", extract_marc("245abcfgknps", alternate_script: false, first: true)

# Creator/contributor fields
to_field "creator_txt", extract_marc("245c:100abcdejlmnopqrtu:110abcdelmnopt:111acdejlnopt:700abcdejqu:710abcde:711acdej", trim_punctuation: true), delete_if(CORPORATE_NAMES), wrap_begin_end
to_field "creator_authority_record_id_ms", extract_marc("1000:1100:1110")
to_field "creator_real_world_object_uri_ms", extract_marc("1001:1101:1111")

to_field "creator_facet", extract_marc("100abcdq:110abcd:111ancdj:700abcdq:710abcd:711ancdj", trim_punctuation: true), delete_if(CORPORATE_NAMES)
to_field "creator_display", extract_creator, delete_if(CORPORATE_NAMES)
to_field "contributor_display", extract_contributor, delete_if(Proc.new { |v| CORPORATE_NAMES.include?(JSON.parse(v)["name"]) })
to_field "contributor_authority_record_id_ms", extract_marc_subfield_limit("7000:7100:7110", "t", false)
to_field "contributor_real_world_object_uri_ms", extract_marc_subfield_limit("7001:7101:7111", "t", false)

to_field "creator_vern_display", extract_creator_vern, delete_if(CORPORATE_NAMES)
to_field "contributor_vern_display", extract_contributor_vern, delete_if(CORPORATE_NAMES)
to_field "author_sort", extract_marc("100abcdejlmnopqrtu:110abcdelmnopt:111acdejlnopt", trim_punctuation: true, first: true), delete_if(CORPORATE_NAMES)

to_field "lc_call_number_sort", extract_lc_call_number_sort

# Publication fields
# For the imprint, make sure to take RDA-style 264, second indicator = 1
to_field "imprint_display", extract_marc("260abcefg3:264|*1|abc3", alternate_script: false)
to_field "imprint_prod_display", extract_marc("264|*0|abc3", alternate_script: false)
to_field "imprint_dist_display", extract_marc("264|*2|abc3", alternate_script: false)
to_field "imprint_man_display", extract_marc("264|*3|abc3", alternate_script: false)
to_field "imprint_vern_display", extract_marc("260abcefg3:264|*1|abc3", alternate_script: :only)
to_field "imprint_date_display", extract_marc("260c:264|*1|c", trim_punctuation: true)
to_field "imprint_prod_date_display", extract_marc("264|*0|c", trim_punctuation: true)
to_field "imprint_dist_date_display", extract_marc("264|*2|c", trim_punctuation: true)
to_field "imprint_man_date_display", extract_marc("260g:264|*3|c", trim_punctuation: true)
to_field "edition_display", extract_marc("250a:254a", trim_punctuation: true, alternate_script: false)
to_field "pub_date", extract_pub_date
to_field "date_copyright_display", extract_copyright

to_field "pub_location_txt", extract_marc("260a:264a", trim_punctuation: true), wrap_begin_end
to_field "publisher_txt", extract_marc("260b:264b", trim_punctuation: true), wrap_begin_end
to_field "pub_date_sort", marc_publication_date
to_field "pub_date_tdt", extract_pub_datetime

# Physical characteristics fields -3xx
to_field "phys_desc_display", extract_marc("300abcefg3:340abcdefhijkmno")
to_field "duration_display", extract_marc("306a")
to_field "frequency_display", extract_marc("310ab:321ab")
to_field "sound_display", extract_marc("344abcdefgh")
to_field "digital_file_display", extract_marc("347abcdef")
to_field "form_work_display", extract_marc("380a")
to_field "performance_display", extract_marc("382abdenprst")
to_field "music_no_display", extract_marc("383abcde")
to_field "video_file_display", extract_marc("346ab")
to_field "music_format_display", extract_marc("348a")
to_field "music_key_display", extract_marc("384a")
to_field "audience_display", extract_marc("385am")
to_field "creator_group_display", extract_marc("386aim")
to_field "date_period_display", extract_marc("388a")
to_field "collection_ms", extract_marc("973at")
to_field "collection_area_display", extract_marc("974at")

# Date added Fields
to_field "date_added_facet", extract_date_added

# Series fields
to_field "title_series_display", extract_marc("830av:490av:440anpv:800abcdefghjklmnopqrstuv:810abcdeghklmnoprstuv:811acdefghjklnpqstuv", alternate_script: false)
to_field "title_series_vern_display", extract_marc("830av:490av:440anpv:800abcdefghjklmnopqrstuv:810abcdeghklmnoprstuv:811acdefghjklnpqstuv", alternate_script: :only)
# to_field "date_series", extract_marc("362a")

to_field "title_series_txt", extract_marc("830av:490av:440anpv"), wrap_begin_end
to_field "title_series_authority_record_id_ms", extract_marc("8000:8100:8110:8300")

# Note fields
to_field "note_display", extract_marc("500a:508a:511a:515a:518a:521ab:525a:530abcd:533abcdefmn:534pabcefklmnt:538aiu:546ab:550a")
to_field "note_award_display", extract_marc("586a")
to_field "note_with_display", extract_marc("501a")
to_field "note_diss_display", extract_marc("502abcdgo")
to_field "note_biblio_display", extract_marc("504a")
to_field "note_toc_display", extract_marc("505agrt")
to_field "note_restrictions_display", extract_marc("506abcde3")
to_field "note_references_display", extract_marc("510abc")
to_field "note_summary_display", extract_marc("520abc")
to_field "note_cite_display", extract_marc("524a")

# Note Copyright should not display if ind1 = 0.  This ensures that it works if the value is unassigned or 1
to_field "note_copyright_display", extract_marc("540a:542|1*|abcdefghijklmnopqr3:542| *|abcdefghijklmnopqr3")
to_field "note_bio_display", extract_marc("545abu")
to_field "note_finding_aid_display", extract_marc("555abcdu3")
to_field "note_custodial_display", extract_marc("561a")
to_field "note_binding_display", extract_marc("5633a")
to_field "note_related_display", extract_marc("580a")
to_field "note_accruals_display", extract_marc("584a")
to_field "note_local_display", extract_marc("590a")

# Subject fields
to_field "subject_facet", extract_subjects(fields: "600abcdefghklmnopqrstuvxyz:610abcdefghklmnoprstuvxyz:611acdefghjklnpqstuvxyz:630adefghklmnoprstvxyz:647acdgvxyz:648axvyz:650abcdegvxyz:651aegvxyz:653a:654abcevyz:656akvxyz:657avxyz:690abcdegvxyz", separator_codes: %w[v x y z])
to_field "subject_display", extract_subjects(fields: "600abcdefghklmnopqrstuvxyz:610abcdefghklmnoprstuvxyz:611acdefghjklnpqstuvxyz:630adefghklmnoprstvxyz:647acdgvxyz:648axvyz:650abcdegvxyz:651aegvxyz:653a:654abcevyz:656akvxyz:657avxyz:690abcdegvxyz", separator_codes: %w[v x y z])
to_field "subject_topic_facet", extract_subjects(fields: "600abcdq:610ab:611a:630a:650ax:653a:654ab:647acdg", separator_codes: ["x"])
to_field "subject_era_facet", extract_marc("648a:650y:651y:654y:655y:690y:647y", trim_punctuation: true)
to_field "subject_region_facet", marc_geo_facet
to_field "subject_authority_record_id_ms", extract_marc("6000:6100:6110:6300:6470:6480:6500:6510:6540:6560:6570")

to_field "genre_facet", extract_genre
to_field "genre_ms", extract_genre_display
to_field "genre_authority_record_id_ms", extract_marc("6550")


to_field "subject_txt", extract_marc(%W(
  600#{A_TO_U}
  610#{A_TO_U}
  611#{A_TO_U}
  630#{A_TO_U}
  647acdg
  650abcde
  653a:654abcde
                                   ).join(":")), wrap_begin_end
to_field "subject_addl_txt", extract_marc("600vwxyz:610vwxyz:611vwxyz:630vwxyz:647vwxyz:648avwxyz:650vwxyz:651aegvwxyz:654vwxyz:656akvxyz:657avxyz:690abcdegvwxyz"), wrap_begin_end

# Location fields
to_field "call_number_display", extract_marc("HLDhi")
to_field "call_number_txt", extract_marc("HLDhi"), wrap_begin_end
to_field "call_number_alt_display", extract_marc("ITMjk")
to_field "call_number_alt_txt", extract_marc("ITMjk"), wrap_begin_end
to_field "library_facet", extract_library
to_field "location_facet", extract_location_facet

# URL Fields
to_field "url_more_links_display", extract_url_more_links
to_field("electronic_resource_display", extract_electronic_resource, &sort_electronic_resource!)
to_field "url_finding_aid_display", extract_url_finding_aid

# Hathitrust Identifier fields
to_field "hathi_trust_bib_key_display", lookup_hathi_bib_key

# Donor Info fields
to_field "donor_info_ms", extract_donor

# Availability
to_field "availability_facet", extract_availability
to_field "location_display", extract_marc("HLDbc")
to_field "holdings_display", extract_marc("HLD8")
to_field "suppress_items_b", suppress_items
to_field "items_json_display", extract_item_info

# Identifier fields
# include unicode normalize for thread safety
to_field("isbn_display",  extract_marc("020a", separator: nil), &normalize_isbn)
to_field("alt_isbn_display",  extract_marc("020z:776z", separator: nil), &normalize_isbn)
to_field("issn_display", extract_marc("022a", separator: nil), &normalize_issn)
to_field("alt_issn_display", extract_marc("022lz:776x", separator: nil), &normalize_issn)
to_field("lccn_display", extract_marc("010ab", separator: nil), &normalize_lccn)
to_field "pub_no_display", extract_marc("028ab")
to_field "sudoc_display", extract_marc("086|0*|a")
to_field "gpo_display", extract_marc("074a")
to_field "oclc_number_display", extract_oclc_number
to_field "alma_mms_display", extract_marc("001")

# Preceding Entry fields
to_field "continues_display", extract_marc("780|00|iabdghkmnopqrstuxyz3:780|02|iabdghkmnopqrstuxyz3", trim_punctuation: true)
to_field "continues_in_part_display", extract_marc("780|01|iabdghkmnopqrstuxyz3:780|03|iabdghkmnopqrstuxyz3", trim_punctuation: true)
to_field "formed_from_display", extract_marc("780|04|iabdghkmnopqrstuxyz3", trim_punctuation: true)
to_field "absorbed_display", extract_marc("780|05|iabdghkmnopqrstuxyz3", trim_punctuation: true)
to_field "absorbed_in_part_display", extract_marc("780|06|iabdghkmnopqrstuxyz3", trim_punctuation: true)
to_field "separated_from_display", extract_marc("780|07|iabdghkmnopqrstuxyz3", trim_punctuation: true)

# Succeeding Entry fields
to_field "continued_by_display", extract_marc("785|00|iabdghkmnopqrstuxyz3:785|02|iabdghkmnopqrstuxyz3", trim_punctuation: true)
to_field "continued_in_part_by_display", extract_marc("785|01|iabdghkmnopqrstuxyz3:785|03|iabdghkmnopqrstuxyz3", trim_punctuation: true)
to_field "absorbed_by_display", extract_marc("785|04|iabdghkmnopqrstuxyz3", trim_punctuation: true)
to_field "absorbed_in_part_by_display", extract_marc("785|05|iabdghkmnopqrstuxyz3", trim_punctuation: true)
to_field "split_into_display", extract_marc("785|06|iabdghkmnopqrstuxyz3", trim_punctuation: true)
to_field "merged_to_form_display", extract_marc("785|07|iabdghkmnopqrstuxyz3", trim_punctuation: true)
to_field "changed_back_to_display", extract_marc("785|08|iabdghkmnopqrstuxyz3", trim_punctuation: true)

# Boost records with holdings from specific libraries
# we actually want to negative boost specific libraries, but that is not possible
# so we are going to boost everything except the less relevant libraries
# TODO: Remove library_based_boost_t once the generic boosting is in production and working.
to_field "library_based_boost_txt", library_based_boost

# Allows label specific boost.
to_field "boost_txt", add_boost_labels

to_field "bound_with_ids", extract_marc("ADFa")
to_field "purchase_order", extract_purchase_order

# Administrative data enrichment fields
# a=create date, b=update date, c=Suppress from publishing, d=Originating system, e=Originating system ID, f=Originating system version
to_field "record_creation_date", extract_marc("ADMa"), default("2001-01-01 01:01:01")
to_field "record_update_date", extract_update_date, default("2002-02-02 02:02:02")
