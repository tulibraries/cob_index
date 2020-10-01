# frozen_string_literal: true

require "rsolr"
require "coveralls"
Coveralls.wear!

require "bundler/setup"
require "cob_index"

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = ".rspec_status"

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end
end

RSpec::Matchers.define :include_items do |primary_items|
  chain :before, :secondary_items
  chain :within_the_first, :within_index

  match do |items|
    all_present?(primary_items, @within_index) &&
      all_present?(@secondary_items) &&
      comes_before?(@secondary_items, primary_items)
  end

  def all_present?(check_items, within_index = nil)
    # Skip if chained check is not required
    return true if check_items.nil?

    @within_items = within_index ? @actual.take(within_index.to_i) : @actual
    check_items.all? { |id| @within_items.include?(id) }
  end

  def comes_before?(back_items, front_items)
    # Skip if chained check is not required
    return true if @secondary_items.nil?

    back_items.all? { |back_item|
      front_items.all? { |front_item|
        @actual.index(back_item) > @actual.index(front_item) rescue false
      }
    }
  end

  failure_message do |actual|
    if secondary_items
      not_found_items = secondary_items.select { |id| !@actual.include? id }
      if not_found_items.present?
        "expected that secondary items #{secondary_items.pretty_inspect} would all be present #{within_index}, but missing #{not_found_items.pretty_inspect}"
      else
        "expected that #{primary_items} would be appear before #{secondary_items} in #{@actual}"
      end
    elsif within_index
      not_found_items = primary_items.select { |id| !@within_items.include? id }

      "expected that primary items #{primary_items.pretty_inspect} would appear in the first #{within_index} items, but missing #{not_found_items.pretty_inspect}"
    else
      not_found_items = primary_items.select { |id| !@actual.include? id }
      "expected that all primary_items (#{primary_items.pretty_inspect}) would apper in results: #{@actual.pretty_inspect}, but missing #{not_found_items.pretty_inspect}"
    end
  end
end
