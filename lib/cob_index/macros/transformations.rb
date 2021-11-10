# frozen_string_literal: true

module CobIndex::Macros::Transformations
  def filter_values(list)
    -> (value, acc) {
      acc.select! do |v|
        !list.include?(v)
      end
    }
  end
end
