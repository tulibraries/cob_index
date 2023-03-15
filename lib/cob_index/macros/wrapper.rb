
# frozen_string_literal: true

module CobIndex::Macros::Wrapper

  START_MATCHER = "matchbeginswith"
  END_MATCHER = "matchendswith"

  def wrap_begin_end(*args)
    lambda do |record, accumulator, context|
      accumulator.map! { |v| self.flank v }
    end
  end


  def first_word_matcher(string="", start_matcher = START_MATCHER)
    start_matcher + string.to_s.split.first.to_s
  end

  def last_word_matcher(string="", end_matcher = END_MATCHER)
    end_matcher + string.to_s.split.last.to_s
  end


  def add_first_word_matcher(string="", start_matcher = START_MATCHER)
    starts ||= START_MATCHER
    first_word = first_word_matcher(string, starts)

    if !string.to_s.empty? && !string.match(/^#{starts}/)
      "#{first_word} #{string}"
    else
      string
    end
  end

  def add_last_word_matcher(string="", end_matcher = END_MATCHER)
    ends ||= END_MATCHER
    last_word = last_word_matcher(string, ends)

    if !string.to_s.empty? && !string.match(/#{ends}/)
      "#{string} #{last_word}"
    else
      string
    end
  end

  def flank(string = "", starts = nil, ends = nil)
    string = add_first_word_matcher(string, starts)
    string = add_last_word_matcher(string, ends)
  end
end
