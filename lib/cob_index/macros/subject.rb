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

    # Extract the allowed subfield codes from the fields argument
    allowed_subfields = fields.split(":").flat_map do |field_code|
      # Assuming fields are separated as '600abcdq' or similar; splitting based on this.
      # This ensures only the valid subfield codes are considered.
      field_code.chars
    end

    field.subfields.each_with_index do |sf, index|
      # Skip subfields not in the allowed subfields list
      next unless allowed_subfields.include?(sf.code)

      value = CobIndex::Macros::Marc21.trim_punctuation(sf.value)

      # Apply separator only for subfields with the code in separator_codes
      if separator_codes.include?(sf.code) && index > 0
        subfield_values << SEPARATOR + value
      else
        subfield_values << value
      end
    end

    # Join the subfield values and add them to the accumulator if there are any non-excluded subfields
    acc << subfield_values.join(" ") unless subfield_values.empty?
  end

  def extract_subjects(fields:, separator_codes:)
    lambda do |record, acc|
      subjects = []

      # Collect the subject fields from the record
      subject_fields = Traject::MarcExtractor.cached(fields).collect_matching_lines(record) do |field, _, _|
        field
      end

      # Sort the fields by tag
      subject_fields.sort_by!(&:tag)

      # Process the fields and add them to the subjects array
      subject_fields.each do |field|
        process_subject_fields(field, subjects, separator_codes: separator_codes, fields: fields)
      end

      # Use the result of the remediation
      subjects = remediate_subjects(subjects)

      # Remove duplicates, flatten, and finalize the list of subjects
      subjects = subjects.flatten.uniq
      acc.replace(subjects)
    end
  end
end
