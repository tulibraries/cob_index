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

  def remediate_subjects(subjects)
    translation_map = Traject::TranslationMap.new("subject_remediation")

    subjects.map do |subject|
      parts = subject.split(SEPARATOR).map(&:strip)
      parts.map! { |part| translation_map[part] || part }
      parts.join(SEPARATOR)
    end
  end

  def process_subject_fields(field, acc, separator_codes:, fields:)
    subfield_values = []

    allowed_subfields = fields.split(":").flat_map do |field_code|
      field_code.chars
    end

    field.subfields.each_with_index do |sf, index|
      next unless allowed_subfields.include?(sf.code)

      value = CobIndex::Macros::Marc21.trim_punctuation(sf.value)

      if separator_codes.include?(sf.code) && index > 0
        subfield_values << SEPARATOR + value
      else
        subfield_values << value
      end
    end

    acc << subfield_values.join(" ") unless subfield_values.empty?
  end

  def extract_subjects(fields:, separator_codes:)
    lambda do |record, acc|
      subjects = []

      subject_fields_with_index = Traject::MarcExtractor.cached(fields).collect_matching_lines(record) do |field, _, _|
        field
      end.each_with_index.map { |field, index| { field: field, original_index: index } }

      subject_fields_with_index.sort_by! { |item| [item[:field].tag, item[:original_index]] }

      sorted_subject_fields = subject_fields_with_index.map { |item| item[:field] }

      sorted_subject_fields.each do |field|
        process_subject_fields(field, subjects, separator_codes: separator_codes, fields: fields)
      end

      subjects = remediate_subjects(subjects)
      subjects = subjects.flatten.uniq
      acc.replace(subjects)
    end
  end
end
