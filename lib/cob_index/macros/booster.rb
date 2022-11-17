# frozen_string_literal: true

require "traject"

# This module has macros and methods related to boosting labels and fields.

module CobIndex::Macros::Booster
  # By convention we append "inverse_boost" or "boost" to the start of the labels as a signal to intent.
  # Of course, how the label is actually being used depends on what is happening in the Solr configuration,
  # or the query context.
  def add_boost_labels
    lambda do |rec, acc|
      add_libraries_labels(rec, acc)
      add_booksellers_labels(rec, acc)
    end
  end

  private

    def add_libraries_labels(rec, acc)
      extractor = Traject::MarcExtractor.cached("HLDb")
      libraries = extractor.extract(rec)

      # In ruby [].all? is true
      return if libraries.empty?

      if libraries.all? { |l| [ "PRESSER", "CLAEDTECH" ].include? l }
        acc << "inverse_boost_libraries"
      end
    end

    def add_booksellers_labels(rec, acc)
      extractor = Traject::MarcExtractor.cached(CobIndex::GENRE_FACET_SPEC)
      genres = extractor.extract(rec)

      return if genres.empty?
      acc << "inverse_boost_bookseller" if genres.any? { |g| g.match(/Bookseller/i) }
    end
end
