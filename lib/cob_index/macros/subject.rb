# frozen_string_literal: true

require "bundler/setup"
require "active_support/core_ext/object/blank"
require "traject"
require "traject/macros/marc21"

module CobIndex::Macros::Subject
  # Remediable subjects are found in any of these fields and subfields:
  REMEDIATED_FIELDS = {
    "650" => "axz",
    "651" => "az",
    "653" => "a"
  }

  SEPARATOR = " — "

  def deprecated_subjects_for_search(subjects)
    reversed_translation_map ||= Traject::TranslationMap.new("subject_remediation").to_hash.invert
    subjects.map { |s| reversed_translation_map[s] }.compact.uniq
  end

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

  def extract_subjects(fields:, separator_codes:, deprecated: false)
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

      subjects = subjects.flatten.uniq
      remediated_subjects = subjects.select do |subject|
        REMEDIATED_FIELDS.keys.any? { |tag| fields.include?(tag) }
      end

      if deprecated
        acc.replace((remediate_subjects(remediated_subjects) + deprecated_subjects_for_search(remediated_subjects)).uniq)
      else
        acc.replace(remediate_subjects(remediated_subjects))
      end
    end
  end

  def remediated_marc_geo_facet(options: {})
    a_fields_spec = options[:geo_a_fields] || "651a:691a"
    z_fields_spec = options[:geo_z_fields] || "600:610:611:630:648:650:654:655:656:690:651:691"

    a_tags = a_fields_spec.split(":").map { |f| f[0..2] }.uniq
    z_tags = z_fields_spec.split(":").map { |f| f[0..2] }.uniq

    lambda do |record, acc|
      # Handle 043a region codes
      Traject::MarcExtractor.new("043a", separator: nil).extract(record).each do |code|
        acc << code.gsub(/\-+\Z/, "")
      end

      # Handle region facets from z_fields and a_fields
      (a_tags + z_tags).uniq.each do |tag|
        record.fields(tag).each do |field|
          field.subfields.each do |sf|
            # Only process subfield "a" for a_tags, and "z" for z_tags
            next unless (a_tags.include?(tag) && sf.code == "a") ||
                        (z_tags.include?(tag) && sf.code == "z")

            cleaned = sf.value.strip.sub(/\. */, "")
            remediated = remediate_subjects([cleaned]).first
            next unless remediated

            if remediated.include?(" -- ")
              acc << remediated.gsub(" -- ", " (") + ")"
            else
              acc << remediated
            end
          end
        end
      end

      acc.uniq!
    end
  end
end
