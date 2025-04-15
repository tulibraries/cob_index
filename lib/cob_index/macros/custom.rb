# frozen_string_literal: true

require "bundler/setup"
require "library_stdnums"
require "active_support/core_ext/object/blank"
require "time"
require "lc_solr_sortable"

# A set of custom traject macros (extractors and normalizers) used by the
module CobIndex::Macros::Custom
  ARCHIVE_IT_LINKS = "archive-it.org/collections/"
  NOT_FULL_TEXT = /book review|publisher description|sample text|View cover art|Image|cover image|table of contents/i
  GENRE_STOP_WORDS = CobIndex::Util.load_list_file("genre_stop_words").to_regex
  SEPARATOR = " — "
  A_TO_Z = ("a".."z").to_a.join("")

  def get_xml
    lambda do |rec, acc|
      acc << MARC::FastXMLWriter.encode(rec)
    end
  end

  def to_single_string
    Proc.new do |rec, acc|
      acc.replace [acc.join(" ")] # turn it into a single string
    end
  end

  def creator_name_trim_punctuation(name)
    name.sub(/ *[,\/;:] *\Z/, "").sub(/( *[[:word:]]{3,})\. *\Z/, '\1').sub(/(?<=\))\./ , "")
  end

  def creator_role_trim_punctuation(role)
    role.sub(/ *[ ,.\/;:] *\Z/, "")
  end

  def extract_title_statement
    lambda do |rec, acc|
      titles = []
      slash = "/"

      Traject::MarcExtractor.cached("245abcfgknps", alternate_script: false).collect_matching_lines(rec) do |field, spec, extractor|
        title = extractor.collect_subfields(field, spec).find { |t| t.present? }
        # Use 245c when 245h is present.
        if field["h"].present? && field["c"].present?
          title = title&.gsub(" #{field['c']}", " #{slash} #{field['c']}")
          title = title&.gsub("/ /", "/")
        end

        titles << title unless title.blank?
      end

      if titles.empty?
        record_id = rec.fields("001").first
        puts "Error: No title found for #{record_id}"
        Traject::MarcExtractor.cached("245#{A_TO_Z}", alternate_script: false).collect_matching_lines(rec) do |field, spec, extractor|
          title = extractor.collect_subfields(field, spec).find { |t| t.present? }
          titles << title unless title.blank?
        end
      end

      acc.replace(titles)
    end
  end


  def extract_title_and_subtitle
    lambda do |rec, acc|
      titles = []

      Traject::MarcExtractor.cached("245abfgknps", alternate_script: false).collect_matching_lines(rec) do |field, spec, extractor|
        title = extractor.collect_subfields(field, spec).find { |t| t.present? }

        if field["c"].present?
          title = title&.chomp("/")&.rstrip
        end

        titles << title unless title.blank?
      end

      if titles.empty?
        record_id = rec.fields("001").first
        puts "Error: No title found for #{record_id}"
        Traject::MarcExtractor.cached("245#{A_TO_Z}", alternate_script: false).collect_matching_lines(rec) do |field, spec, extractor|
          title = extractor.collect_subfields(field, spec).find { |t| t.present? }
          titles << title unless title.blank?
        end
      end

      acc.replace(titles)
    end
  end

  def extract_date_added
    lambda do |rec, acc|
      rec.fields(["997"]).each do |field|
        acc << field["a"].ljust(8, "0")[0..7].to_i unless field["a"].nil?
      end
    end
  end

  def extract_creator
    lambda do |rec, acc|
      s_fields = Traject::MarcExtractor.cached("100abcqd:100ejlmnoprtu:110abdc:110elmnopt:111andcj:111elopt", alternate_script: false).collect_matching_lines(rec) do |field, spec, extractor|
        extractor.collect_subfields(field, spec).first
      end

      grouped_subfields = s_fields.each_slice(2).to_a
      grouped_subfields.each do |link|
        name = creator_name_trim_punctuation(link[0]) unless link[0].nil?
        role = creator_role_trim_punctuation(link[1]) unless link[1].nil?
        acc << [name, role].compact.join("|")
      end
      acc
    end
  end

  def extract_creator_vern
    lambda do |rec, acc|
      s_fields = Traject::MarcExtractor.cached("100abcqd:100ejlmnoprtu:110abdc:110elmnopt:111andcj:111elopt", alternate_script: :only).collect_matching_lines(rec) do |field, spec, extractor|
        extractor.collect_subfields(field, spec).first
      end

      grouped_subfields = s_fields.each_slice(2).to_a
      grouped_subfields.each do |link|
        name = creator_name_trim_punctuation(link[0]) unless link[0].nil?
        role = creator_role_trim_punctuation(link[1]) unless link[1].nil?
        acc << [name, role].compact.join("|")
      end
      acc
    end
  end

  def extract_contributor
    lambda do |rec, acc|
      s_fields = Traject::MarcExtractor.cached("700i:700abcqd:700ejlmnoprtu:710i:710abdc:710elmnopt:711i:711andcj:711elopt", alternate_script: false).collect_matching_lines(rec) do |field, spec, extractor|
        extractor.collect_subfields(field, spec).first
      end
      s_fields.each_slice(3) do |link|
        link[1] = creator_name_trim_punctuation(link[1]) unless link[1].nil?
        link[2] = creator_role_trim_punctuation(link[2]) unless link[2].nil?
        acc << ["relation", "name", "role"].zip(link).to_h.reject { |k, v| v.nil? }.to_json
      end
      acc
    end
  end

  def extract_contributor_vern
    lambda do |rec, acc|
      s_fields = Traject::MarcExtractor.cached("700abcqd:700ejlmnoprtu:710abdc:710elmnopt:711andcj:711elopt", alternate_script: :only).collect_matching_lines(rec) do |field, spec, extractor|
        extractor.collect_subfields(field, spec).first
      end

      grouped_subfields = s_fields.each_slice(2).to_a
      grouped_subfields.each do |link|
        name = creator_name_trim_punctuation(link[0]) unless link[0].nil?
        role = creator_role_trim_punctuation(link[1]) unless link[1].nil?
        acc << [name, role].compact.join("|")
      end
      acc
    end
  end

  def extract_uniform_title
    # Note that this method previously included tag 730 which was moved to addl title
    lambda do |rec, acc|
      s_fields = Traject::MarcExtractor.cached("130adfklmnoprs:240adfklmnoprs", alternate_script: false).collect_matching_lines(rec) do |field, spec, extractor|
        extractor.collect_subfields(field, spec).first
      end
      s_fields.each_slice(2) do |link|
        if link.count == 2
          acc << ["relation", "title"].zip(link).to_h.reject { |k, v| v.nil? }.to_json
        else
          acc << ["title"].zip(link).to_h.reject { |k, v| v.nil? }.to_json
        end
      end
      acc
    end
  end

  def extract_additional_title
    lambda do |rec, acc|
      s_fields = Traject::MarcExtractor.cached("210ab:246i:246abfgnp:247abcdefgnp:730i:730al:740anp", alternate_script: false).collect_matching_lines(rec) do |field, spec, extractor|
        value  = extractor.collect_subfields(field, spec).first

        if (spec.tag == "246" || spec.tag == "730") && spec.subfields == ["i"]
          { "relation" => value }
        else
          { "title" => value }
        end
      end

      relation = nil
      s_fields.each do |value|
        if relation && value["title"].present?
          acc << relation.merge(value).to_json
          relation = nil
        elsif value["relation"].present?
          relation = value.dup
        elsif value["title"].present?
          acc << value.to_json
        end
      end
    end
  end

  def subject_translations(subject)
    translations = { "Aliens" => "Noncitizens",
      "Illegal aliens" => "Undocumented immigrants",
      "Alien criminals" => "Noncitizen criminals",
      "Alien detention centers" => "Noncitizen detention centers",
      "Alien property" => "Noncitizen property",
      "Aliens in art" => "Noncitizens in art",
      "Aliens in literature" => "Noncitizens in literature",
      "Aliens in mass media" => "Noncitizens in mass media",
      "Aliens in motion pictures" => "Noncitizens in motion pictures",
      "America, Gulf of" => "Mexico, Gulf of",
      "Children of illegal aliens" => "Children of undocumented immigrants",
      "Church work with aliens" => "Church work with noncitizens",
      "Illegal alien children" => "Undocumented immigrant children",
      "Illegal aliens in literature" => "Undocumented immigrants in literature",
      "McKinley, Mount" => "Denali, Mount",
      "Women illegal aliens" =>  "Women undocumented immigrants",
    }

    translations.default_proc = proc { |hash, key|
      key2 = key.gsub(/\.$/, "")
      if translations.key? key2
        hash[key2]
      else
        subject
      end
    }

    translations[subject]
  end

  def translate_subject_field!(field)
    fields = ["650", "651", "653"]
    codes = ["a", "z"]

    if fields.include? field.tag
      field.subfields.map! { |sf|
        if codes.include? sf.code
          sf.value = subject_translations(sf.value) unless field.tag == "653" && sf.code == "z"
          sf
        end
      }
    end
  end

  def extract_subject_display
    lambda do |rec, acc|
      subjects = []
      Traject::MarcExtractor.cached("600abcdefghklmnopqrstuvxyz:610abcdefghklmnoprstuvxyz:611acdefghjklnpqstuvxyz:630adefghklmnoprstvxyz:647acdgvxyz:648axvyz:650abcdegvxyz:651aegvxyz:653a:654abcevyz:656akvxyz:657avxyz:690abcdegvxyz").collect_matching_lines(rec) do |field, spec, extractor|
        translate_subject_field!(field)
        subject = extractor.collect_subfields(field, spec).first
        unless subject.nil?
          field.subfields.each do |s_field|
            subject = subject.gsub(" #{s_field.value}", "#{SEPARATOR}#{s_field.value}") if (s_field.code == "v" || s_field.code == "x" || s_field.code == "y" || s_field.code == "z")
          end
          subject = subject.split(SEPARATOR)
          subjects << subject.map { |s| CobIndex::Macros::Marc21.trim_punctuation(s) }.join(SEPARATOR)
        end
        subjects
      end

      acc.replace(subjects)
    end
  end

  def extract_genre_display
    lambda do |rec, acc|
      genres = []
      Traject::MarcExtractor.cached("655abcvxyz").collect_matching_lines(rec) do |field, spec, extractor|
        genre = extractor.collect_subfields(field, spec).first
        unless genre.nil?
          field.subfields.each do |s_field|
            genre = genre.gsub(" #{s_field.value}", "#{SEPARATOR}#{s_field.value}") if (s_field.code == "v" || s_field.code == "x" || s_field.code == "y" || s_field.code == "z")
          end
          genre = genre.split(SEPARATOR)
          genres << genre.map { |s| CobIndex::Macros::Marc21.trim_punctuation(s) }.join(SEPARATOR)
        end
        genres
      end
      acc.replace(genres)
    end
  end

  def extract_subject_topic_facet
    lambda do |rec, acc|
      subjects = []
      Traject::MarcExtractor.cached("600abcdq:610ab:611a:630a:653a:654ab:647acdg").collect_matching_lines(rec) do |field, spec, extractor|
        subject = extractor.collect_subfields(field, spec).fetch(0, "")
        subject = subject.split(SEPARATOR)
        subjects << subject.map { |s| CobIndex::Macros::Marc21.trim_punctuation(s) }
      end

      Traject::MarcExtractor.cached("650ax").collect_matching_lines(rec) do |field, spec, extractor|
        translate_subject_field!(field)
        subject = extractor.collect_subfields(field, spec).first
        unless subject.nil?
          field.subfields.each do |s_field|
            if (s_field.code == "x")
              subject = subject.gsub(" #{s_field.value}", "#{SEPARATOR}#{s_field.value}")
            end
          end
          subject = subject.split(SEPARATOR)
          subjects << subject.map { |s| CobIndex::Macros::Marc21.trim_punctuation(s) }.join(SEPARATOR)
        end
      end
      subjects = subjects.flatten
      acc.replace(subjects)
      acc.uniq!
    end
  end

  def extract_electronic_resource
    lambda do |rec, acc, context|
      rec.fields("PRT").each do |f|
        selected_subfields = {
          portfolio_id: f["a"],
          collection_id: f["i"],
          service_id: f["j"],
          title: f["c"],
          coverage_statement: f["g"],
          public_note: f["f"],
          authentication_note: f["k"],
          availability: f["9"] }
          .delete_if { |k, v| v.blank? }
          .to_json
        acc << selected_subfields
      end

      # Short circuit if PRT field present.
      if rec.fields("PRT").present?
        return acc
      end

      rec.fields("856").each do |f|
        if f.indicator2 != "2"
          label = url_label(f["z"], f["3"], f["y"])
          unless f["u"].nil?
            unless NOT_FULL_TEXT.match(label) || f["u"].include?(ARCHIVE_IT_LINKS)
              acc << { title: label, url: f["u"] }.to_json
            end
          end
        end
      end
    end
  end




  # BL-192
  # Sort so that the electronic records are ordered descending by date coverage/starting with the most recent.
  # In the cases where there is multiple coverage statements with overlapping ranges, order by the end date.
  # When there is no end date (ex. Available from ####),  list at top and order by start date, listing those with widest coverage first.
  def sort_electronic_resource!
    lambda do |rec, acc, context|
      begin
        acc.sort_by! { |r|
          subfields = JSON.parse(r)
          available = /Available from \d{2}\/\d{2}\/(\d{4}) until \d{2}\/\d{2}\/(\d{4})?/.match(subfields["coverage_statement"]) ||
                      /Available from \d{2}\/\d{2}\/(\d{4}).?/.match(subfields["coverage_statement"]) ||
                      /Available from (\d{4}) until (\d{4})?/.match(subfields["coverage_statement"]) ||
                      /Available from (\d{4})?/.match(subfields["coverage_statement"]) ||
                      []

          start_year = (available[1] || 1).to_i
          end_year = (available[2] || 9999).to_i
          range = end_year - start_year
          title = subfields["title"].to_s

          # Order by year_end descending.
          # Then descending range (large year span comes first).
          # Then order by ascending title.
          # Then order by ascending subtitle.
          [ 1.0 / end_year, 1.0 / range, title ]
        }
      rescue
        logger.error("Failed `sort_electronic_resource!` on sorting #{rec}")
        acc
      end
    end
  end

  def url_label(z, n, y)
    label = [z, n].compact.join(" ")
    if label.empty?
      label = y || "Link to Resource"
    end
    label
  end

  def extract_url_more_links
    lambda { |rec, acc|
      # Short circuit if PRT field present.
      if rec.fields("PRT").present?
        return acc
      end

      rec.fields("856").each do |f|
        label = url_label(f["z"], f["3"], f["y"])
        unless f["u"].nil?
          if f.indicator2 == "2" || NOT_FULL_TEXT.match(label) || !rec.fields("PRT").empty? || f["u"].include?(ARCHIVE_IT_LINKS)
            unless finding_aid?(f["u"])
              acc << { title: label, url: f["u"] }.to_json
            end
          end
        end
      end
    }
  end

  def extract_url_finding_aid
    lambda { |rec, acc|
      rec.fields("856").each do |f|
        label = url_label(f["z"], f["3"], f["y"])
        if f.indicator1 == "4" && f.indicator2 == "2"
          unless f["u"].nil?
            if finding_aid?(f["u"])
              acc << { title: label, url: f["u"] }.to_json
            end
          end
        end
      end
    }
  end

  def finding_aid?(url)
    url.match?(/http[s]*:\/\/scrcarchivesspace.temple.edu/) ||
    (url.match?(/http[s]*:\/\/library.temple.edu/) && url.match?(/scrc|finding-aids|finding_aids/))
  end

  def extract_availability
    lambda { |rec, acc, context|
      if context.output_hash["hathi_trust_bib_key_display"].present?
        if context.output_hash["hathi_trust_bib_key_display"].any? { |htbk| htbk.include?("allow") }
          acc << "Online"
        else
          acc << "ETAS"
        end
      end
      unless rec.fields("PRT").empty?
        rec.fields("PRT").each do |field|
          unless field["9"] == "Not Available"
            acc << "Online"
          end
        end
      end
      unless acc.include?("Online") || acc.include?("Online+Etas")
        rec.fields(["856"]).each do |field|
          z3 = [field["z"], field["3"]].join(" ")
          unless field["u"].nil?
            unless NOT_FULL_TEXT.match(z3) || rec.fields("856").empty? || field["u"].include?(ARCHIVE_IT_LINKS)
              if field.indicator1 == "4" && field.indicator2 != "2"
                acc << "Online"
              end
            end
          end
        end
      end

      unless rec.fields("HLD").empty?
        acc << "At the Library"
      end

      unless rec.fields("ADF").empty?
        acc << "At the Library"
      end

      order = []
      extract_purchase_order[rec, order]
      if order == [true]
        acc << "Request Rapid Access"
        acc << "Online"
      end

      acc.uniq!
    }
  end

  def extract_genre
    lambda do |rec, acc|
      Traject::MarcExtractor.cached(CobIndex::GENRE_FACET_SPEC).collect_matching_lines(rec) do |field, spec, extractor|
        genre = extractor.collect_subfields(field, spec).first
        unless genre.nil?
          unless GENRE_STOP_WORDS.match(genre.force_encoding(Encoding::UTF_8).unicode_normalize)
            acc << genre.gsub(/[^[:alnum:])]*$/, "")
          end
        end
        acc.uniq!
      end
    end
  end

  def normalize_format
    Proc.new do |rec, acc|
      acc.delete("Print")
      acc.delete("Online")
      # replace Archival with Archival Material
      acc.map! { |x| x == "Archival" ? "Archival Material" : x }.flatten!
      # replace Conference with Conference Proceedings
      acc.map! { |x| x == "Conference" ? "Conference Proceedings" : x }.flatten!
    end
  end

  def normalize_isbn
    Proc.new do |rec, acc|
      orig = acc.dup
      acc.map! { |x| StdNum::ISBN.allNormalizedValues(x) }
      acc << orig
      acc.flatten!
      acc.uniq!
    end
  end

  def normalize_issn
    Proc.new do |rec, acc|
      orig = acc.dup
      acc.map! { |x| StdNum::ISSN.normalize(x) }
      acc << orig
      acc.flatten!
      acc.uniq!
    end
  end

  def normalize_lccn
    Proc.new do |rec, acc|
      acc.map! { |x|
        formatted_x = x.gsub("#", " ")
        StdNum::LCCN.normalize(formatted_x) }
      acc.uniq!
    end
  end

  def truncate(max = 300)
    Proc.new do |_, acc|
      acc.map! { |s| s.length > max ? s[0...max] + " ..." : s unless s.nil? }
    end
  end

  # Just like marc_languages except it makes a special case for "041a" spec.
  def extract_lang(spec = "008[35-37]:041a:041d")
    translation_map = Traject::TranslationMap.new("marc_languages")

    extractor = Traject::MarcExtractor.new(spec, separator: nil)
    spec_041a = Traject::MarcExtractor::Spec.new(tag: "041", subfields: ["a"])

    lambda do |record, accumulator|
      codes = extractor.collect_matching_lines(record) do |field, spec, extractor|
        if extractor.control_field?(field)
          (spec.bytes ? field.value.byteslice(spec.bytes) : field.value)
        else
          extractor.collect_subfields(field, spec).collect do |value|
            # sometimes multiple language codes are jammed together in one subfield, and
            # we need to separate ourselves. sigh.
            if spec == spec_041a
              value = value[0..2]
            end

            unless value.length == 3
              # split into an array of 3-length substrs; JRuby has problems with regexes
              # across threads, which is why we don't use String#scan here.
              value = value.chars.each_slice(3).map(&:join)
            end
            value
          end.flatten
        end
      end
      codes = codes.uniq

      translation_map.translate_array!(codes)

      accumulator.concat codes
    end
  end

  def library_and_locations(rec)
    libraries_map = Traject::TranslationMap.new("libraries_map")
    locations_map = Traject::TranslationMap.new("locations")

    rec.fields(["ITM"]).reduce([]) do |acc, field|
      library = field["f"]
      status = field["u"]
      location = field["g"]
      location = "ASRS" if library == "ASRS"

      next acc if [ "RES_SHARE", "KIOSK" ].include?(library) ||
        [ "EMPTY", "LOST_LOAN", "LOST_LOAN_AND_PAID", "MISSING",  "TECHNICAL", "UNASSIGNED"].include?(status) ||
        [ "UNASSIGNED" ].include?(location) || location.blank?

      acc << {
        library: libraries_map[library] || library,
        current_location: (locations_map[library][location] rescue location)
      }
    end
  end

  def extract_library
    lambda do |rec, acc|
      acc.replace library_and_locations(rec).map { |r| r[:library] }.uniq
    end
  end

  def extract_location_facet
    lambda do |rec, acc|
      acc.replace library_and_locations(rec).map { |r|
        r.slice(:library, :current_location).values.join(" - ")
      }
    end
  end

  def extract_pub_date
    lambda do |rec, acc|
      rec.fields(["008"]).each do |field|
        # [TODO] date_pub_status for future use. How should we display date data depending on value of date_pub_status?
        date_pub_status = Traject::TranslationMap.new("marc_date_type_pub_status")[field.value[6]]
        date1 = field.value[7..10]
        # [TODO] date2 for future use. How should we display dates if there are a date1 and date2?
        date2 = field.value[11..14]
        acc << date1 unless date1.nil?
      end
    end
  end

  def extract_pub_datetime
    lambda do |rec, acc|
      rec.fields(["260"]).each do |field|
        acc << four_digit_year(field["c"]) unless field["c"].nil?
      end

      rec.fields(["264"]).each do |field|
        acc << four_digit_year(field["c"]) unless field["c"].nil? || field.indicator2 == "4"
      end
      if !acc.empty?
        acc.replace [Date.ordinal(acc.first.to_i, 1).strftime("%FT%TZ")]
      end
    end
  end

  def extract_copyright
    lambda do |rec, acc|
      rec.fields(["264"]).each do |field|
        acc << four_digit_year(field["c"]) if field.indicator2 == "4"
      end
    end
  end

  def suppress_items
    lambda do |rec, acc, context|
      full_text_link = rec.fields("856").select { |field| field["u"] unless field.indicator2 == "2" }
      purchase_order_item = rec.fields("902").select { |field| field["a"].match?(/EBC-POD/) if field["a"] }
      unwanted_library = rec.fields("HLD").select { |field| field["b"] == "EMPTY" || field["c"] == "UNASSIGNED" || field["c"] == "intref" || field["c"] == "techserv" }
      u_subfields = []
      rec.fields("ITM").select { |field|
        u_subfields << field["u"]
      }
      acc.replace([true]) if rec.fields("HLD").length == 0 && (rec.fields("PRT").length == 0 && full_text_link.empty?) && purchase_order_item.empty?
      acc.replace([true]) if rec.fields("ITM").length >= 1 && u_subfields.all? { |f| f == "LOST_LOAN" || f == "LOST_LOAN_AND_PAID" || f == "MISSING" || f == "TECHNICAL" || f == "UNASSIGNED" }
      acc.replace([true]) if rec.fields("HLD").length == 1 && !unwanted_library.empty?

      acc.replace([true]) if rec.fields("PRT").present? &&
        rec.fields("PRT").all? { |f| f["9"] == "Not Available" }

      if acc == [true] && ENV["TRAJECT_FULL_REINDEX"] == "yes"
        context.skip!
      end
    end
  end

  def extract_oclc_number
    lambda do |rec, acc|
      rec.fields(["035", "979"]).each do |field|

        next if field.nil? || field["a"].nil? || field["9"]&.include?("ExL")

        if field["a"].include?("OCoLC") || field["a"].include?("ocn") ||
            field["a"].include?("ocm") || field["a"].match(/\bon[0-9]/) ||
            field["a"].include?("OCLC")

          subfield = (field["a"].split(//) rescue [])
            .map { |x| x[/\d+/] }.join("").sub!(/^0*/, "")
          acc << subfield unless subfield.empty?
        end
      end

      acc.uniq!
    end
  end

  def lookup_hathi_bib_key
    lambda do |rec, acc|
      oclc_nums = []
      extract_oclc_number.call(rec, oclc_nums)
      oclc_nums.map do |oclc_num|
        acc << lookup_hathi_bib_key_in_files(oclc_num)
      end
      acc.uniq!
    end
  end

  def lookup_hathi_bib_key_in_files(oclc_num)
    base_path = __dir__ + "/../../hathi_data"
    trailing_digit = oclc_num[-1]
    line = `egrep -o -m 1 '^.+,.+,#{oclc_num}$' #{base_path}/trailing_#{trailing_digit}.csv`.split(",")
    { bib_key: line[1], access: line[0] }.to_json unless line.empty?
  end

  def extract_item_info
    lambda do |rec, acc, context|
      holding_ids = rec.fields("HLD").map  { |field| field["8"] }.compact.uniq
      item_holding_ids = rec.fields("ITM").map { |field| field["r"] }.compact.uniq
      holding_ids_with_no_items = holding_ids - item_holding_ids

      holding_ids_with_no_items.each  do |holding_id|
        rec.fields("HLD").select { |field| field["8"] == holding_id }.each do |field|
          summary = rec.fields(["HLD866"]).select { |h| h["8"] == field["8"] }
            .map { |h| h["a"] }
            .first

          selected_subfields = {
              holding_id: field["8"],
              current_library: field["b"],
              current_location: field["c"],
              call_number: field["h"].to_s + field["i"].to_s,
              summary: summary }
            .delete_if { |k, v| v.blank? }
            .to_json


          acc << selected_subfields
        end
      end

      rec.fields("ITM").each do |f|
        summary = rec.fields(["HLD866"]).select { |h| h["8"] == f["r"] }
          .map { |h| h["a"] }
          .first

        selected_subfields = {
          item_pid: f["8"],
          item_policy: f["a"],
          description: f["c"],
          permanent_library: f["d"],
          permanent_location: f["e"],
          current_library: f["f"],
          current_location: f["g"],
          call_number_type: f["h"],
          call_number: f["i"],
          alt_call_number_type: f["j"],
          alt_call_number: f["k"],
          temp_call_number_type: f["l"],
          temp_call_number: f["m"],
          public_note: f["o"],
          due_back_date: f["p"],
          holding_id: f["r"],
          material_type: f["t"],
          summary: summary,
          process_type: f["u"] }
          .delete_if { |k, v| v.blank? }
          .to_json

        acc << selected_subfields
      end
    end
  end

  # In order to reduce the relevance of certain libraries, we need to boost every other library
  # Make sure we still boost records what have holdings in less relevant libraries and also in another library
  LIBRARIES_TO_NOT_BOOST = [ "PRESSER", "CLAEDTECH" ]
  def library_based_boost
    lambda do |rec, acc|
      rec.fields(["HLD"]).each do |field|
        if  !LIBRARIES_TO_NOT_BOOST.include?(field["b"])
          acc.replace(["boost"])
          break
        else
          acc << "no_boost"
        end
      end
    end
  end

  def extract_work_access_point
    lambda do |rec, acc|
      if rec["130"].present?
        spec = "130adfklmnoprs"
      elsif rec["240"].present? && rec["100"].present?
        spec = "100abdcdq:240adfklmnoprs"
      elsif rec["240"].present? && rec["110"].present?
        spec = "110abcd:240adfklmnoprs"
      elsif rec["100"]
        spec = "100abcdq:245aknp"
      elsif rec["110"]
        spec = "110abcd:245aknp"
      else
        # Skip because alternative is just the regular title.
        return acc
      end

      acc << Traject::MarcExtractor.cached(spec).extract(rec).join(" . ")
    end
  end

  def extract_purchase_order
    lambda do |rec, acc|
      acc << Traject::MarcExtractor.cached("902a").extract(rec).any? { |s| s.match?(/EBC-POD/) } || false
    end
  end

  def extract_update_date
    lambda do |rec, acc|
      harvest_date = Time.parse(ENV["ALMAOAI_LAST_HARVEST_FROM_DATE"]).utc.to_s rescue nil
      latest_date = [
        [ harvest_date ],
        rec.fields("ADM").map { |f| [ f["a"], f["b"] ] },
        rec.fields("PRT").map { |f| [ f["created"], f["updated"] ] },
        rec.fields("HLD").map { |f| [ f["created"], f["updated"] ] },
        rec.fields("ITM").map { |f| [ f["q"], f["updated"] ] } ]
        .flatten.compact.uniq.map { |t| Time.parse(t).utc }
        .sort.last.to_s

      if latest_date == harvest_date
        record_id = rec.fields("001").first
        puts "Suspected record with un-dated deleted fields: latest_date less than #{harvest_date}, setting date to Time.now: #{record_id}\n"

        latest_date = Time.now.utc.to_s
      end

      if ENV["SOLR_DISABLE_UPDATE_DATE_CHECK"]
        latest_date = Time.now.utc.to_s
      end

      acc << latest_date unless latest_date.empty?
    end
  end

  def build_call_number(rec, tags)
    return nil if tags.empty?
    call_numbers = Traject::MarcExtractor.cached("#{tags.shift}ab", alternate_script: false).collect_matching_lines(rec) do |field, spec, extractor|
      field.subfields.uniq! { |sf| sf.code }
      extracted = extractor.collect_subfields(field, spec).first
    end
    return build_call_number(rec, tags) if call_numbers.empty?
    # take the biggest one if there are several 090 or 050 for some reason
    return call_numbers.compact.reject { |call_number| call_number.empty? }.sort { |call_number| call_number.size }.first
  end

  def extract_lc_outer_facet
    lambda do |rec, acc|
      call_number = build_call_number(rec, ["090", "050"])&.gsub(/\s+/, "")
      next if call_number.nil?
      first_letter = call_number.lstrip.slice(0, 1)
      letters = call_number.match(/^([[:alpha:]]*)/)[0]
      lc1letter = Traject::TranslationMap.new("callnumber_map")[first_letter] unless Traject::TranslationMap.new("callnumber_map")[letters].nil?
      acc.replace [lc1letter]
    end
  end

  def extract_lc_inner_facet
    lambda do |rec, acc|
      call_number = build_call_number(rec, ["090", "050"])&.gsub(/\s+/, "")
      next if call_number.nil?
      first_letter = call_number.lstrip.slice(0, 1)
      letters = call_number.match(/^([[:alpha:]]*)/)[0]
      # TODO: lc1letter (assigned but not used).
      lc1letter = Traject::TranslationMap.new("callnumber_map")[first_letter] unless Traject::TranslationMap.new("callnumber_map")[letters].nil?
      lc_rest = Traject::TranslationMap.new("callnumber_map")[letters]
      acc.replace [lc_rest]
    end
  end

  def extract_lc_call_number_sort
    lambda do |rec, acc|
      call_number = build_call_number(rec, ["090", "050"])&.gsub(/\s+/, "")
      return if call_number.nil?
      begin
        acc << ::LcSolrSortable.convert(call_number)
      rescue Exception => e
        e.message << " call no: #{call_number}"
        raise e
      end
    end
  end

  def extract_lc_call_number_display
    lambda do |rec, acc|
      acc << build_call_number(rec, ["090", "050"])
    end
  end

  def extract_donor
    lambda do |rec, acc|
      rec.fields(["541"]).each do |field|
        subfield_a = field["a"]&.chomp(";")&.strip
        subfield_c = field["c"]&.gsub(/\W/, "")
        if field.indicator1 == "1" && subfield_c == "Gift"
          acc << subfield_a
        end
      end
    end
  end

  def extract_marc_subfield_limit(spec, subfield_limit, subfield_boolean)
    # spec is the standard extract_marc string.
    # subfield_limit is a string of the subfield code used to limit the extracted marc output.
    # subfield_boolean is either true or false.
    # If true, extract_marc_subfield_limit will only extract a field if that field also includes a subfield that matches the subfield_limit code.
    # If false, extract_marc_subfield_limit will only extract a field from spec if it does not include a subfield that matches the subfield_limit code.

    lambda do |rec, acc|
      values = Traject::MarcExtractor.cached(spec).collect_matching_lines(rec) do |field, spec, extractor|
        if (subfield_boolean && field[subfield_limit]) || (!subfield_boolean && !field[subfield_limit])
          results = extractor.collect_subfields(field, spec)
        else
          []
        end
      end.compact
      acc.concat(values)
    end
  end
end
