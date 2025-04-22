# frozen_string_literal: true

require "bundler/setup"
require "active_support/core_ext/object/blank"

module CobIndex::Macros::Subject
  # Remediable subjects are found in any of these fields and subfields:
  REMEDIATED_FIELDS = {
    "650" => "axz",
    "651" => "az",
    "653" => "a"
  }

  SEPARATOR = " — "

  def remediated_subjects
    lambda do |record, acc|
      translation_map = Traject::TranslationMap.new("subject_remediation")

      Traject::MarcExtractor.cached("650axz:651axz:653a").collect_matching_lines(record) do |field, spec, extractor|
        remediated_subjects = []

        field.subfields.each do |sf|
          original_value = CobIndex::Macros::Marc21.trim_punctuation(sf.value)
          translated_value = translation_map[original_value] || original_value
          sf.value = translated_value

          remediated_subjects << translated_value
        end

        acc << remediated_subjects.join(SEPARATOR) unless remediated_subjects.empty?
      end
    end
  end

  def process_subject_fields(field, acc, separator_codes:)
    subfield_values = []

    # Process all subfields
    field.subfields.each_with_index do |sf, index|
      value = CobIndex::Macros::Marc21.trim_punctuation(sf.value)
      prefix = if index.positive? && separator_codes.include?(sf.code)
        SEPARATOR
               else
                 " "
      end

      subfield_values << "#{index.zero? ? value : "#{prefix}#{value}"}"
    end

    acc << subfield_values.join unless subfield_values.empty?
  end

  def extract_subjects(separator_codes:, fields:)
    lambda do |rec, acc|
      subjects = []

      # Collect the fields from the record
      subject_fields = Traject::MarcExtractor.cached(fields).collect_matching_lines(rec) do |field, _, _|
        field
      end

      # Sort fields by tag
      subject_fields.sort_by!(&:tag)

      subject_fields.each do |field|
        # If the field is remediated, process it
        if REMEDIATED_FIELDS.key?(field.tag)
          remediated_subjects.call(rec, subjects)
        end

        # Process the subfields in the field
        process_subject_fields(field, subjects, separator_codes: separator_codes)
      end

      # Flatten and remove duplicates from the final subjects array
      subjects = subjects.flatten.uniq
      acc.replace(subjects)
    end
  end
end
