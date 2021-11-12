# frozen_string_literal: true

module CobIndex::CoreExtensions::Array::Transformation
  def to_regex
    Regexp.new(entries.map { |v| Regexp.escape(v) }.join("|"), true)
  end
end
