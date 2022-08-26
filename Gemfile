# frozen_string_literal: true

source "https://rubygems.org"

git_source(:github) { |repo_name| "https://github.com/#{repo_name}" }

# Specify your gem's dependencies in cob_index.gemspec
gemspec

gem "blacklight-marc"
gem "alma", git: "https://github.com/tulibraries/alma_rb.git", branch: "main"
gem "rsolr"
gem "lc_solr_sortable", git: "https://github.com/tulibraries/lc_solr_sortable", branch: "main"

group :debug do
  gem "binding_of_caller", "~> 1.0", platform: "mri"
  gem "guard", "~> 2.18", platform: "mri"
  gem "guard-rspec", "~> 4.7", platform: "mri"
  gem "pry", "~> 0.14", platform: "mri"
  gem "pry-byebug", "~> 3.10", platform: "mri"
end
