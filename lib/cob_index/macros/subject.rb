# frozen_string_literal: true

require "bundler/setup"
require "active_support/core_ext/object/blank"

# A set of custom traject macros (extractors and normalizers) used for translations
module CobIndex::Macros::Subject
  def topics
    extract_subject_display
  end

  def subject_translations(subject)
    translations = {
      "Aliens" => "Noncitizens",
      "Illegal aliens" => "Undocumented immigrants",
      "Alien criminals" => "Noncitizen criminals",
      "Alien detention centers" => "Noncitizen detention centers",
      "Alien property" => "Noncitizen property",
      "Aliens in art" => "Noncitizens in art",
      "Aliens in literature" => "Noncitizens in literature",
      "Aliens in mass media" => "Noncitizens in mass media",
      "Aliens in motion pictures" => "Noncitizens in motion pictures",
      "Children of illegal aliens" => "Children of undocumented immigrants",
      "Church work with aliens" => "Church work with noncitizens",
      "Illegal alien children" => "Undocumented immigrant children",
      "Illegal aliens in literature" => "Undocumented immigrants in literature",
      "Women illegal aliens" => "Women undocumented immigrants",
    }

    translations.default_proc = proc { |hash, key|
      key2 = key.gsub(/\.$/, "")
      hash[key2] || key
    }

    translations[subject]
  end

  def translate_subject_field!(field)
    # fields = ["650", "651", "653"]
    # codes = ["a", "z"]

    # if fields.include?(field.tag)
    field.subfields.each do |sf|
      if codes.include?(sf.code)
        sf.value = subject_translations(sf.value)#unless field.tag == "653" && sf.code == "z"
      end
    end
    # end
  end

  def extract_subject_display
    lambda do |rec, acc|
      subjects = []
      Traject::MarcExtractor.cached("600abcdefghklmnopqrstuvxyz:610abcdefghklmnoprstuvxyz:611acdefghjklnpqstuvxyz:630adefghklmnoprstvxyz:647acdgvxyz:648axvyz:650abcdegvxyz:651aegvxyz:653a:654abcevyz:656akvxyz:657avxyz:690abcdegvxyz").collect_matching_lines(rec) do |field, spec, extractor|
        translate_subject_field!(field)
        subject = extractor.collect_subfields(field, spec).first
        unless subject.nil?
          field.subfields.each do |s_field|
            if %w[v x y z].include?(s_field.code)
              subject = subject.gsub(" #{s_field.value}", "#{SEPARATOR}#{s_field.value}")
            end
          end
          subject = subject.split(SEPARATOR)
          subjects << subject.map { |s| CobIndex::Macros::Marc21.trim_punctuation(s) }.join(SEPARATOR)
        end
      end
      acc.replace(subjects)
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
            if s_field.code == "x"
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
end
