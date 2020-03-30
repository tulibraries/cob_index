# CobIndex
[![Build Status](https://travis-ci.org/tulibraries/cob_index.svg?branch=master)](https://travis-ci.org/tulibraries/cob_index)
[![Coverage Status](https://coveralls.io/repos/github/tulibraries/cob_index/badge.svg?branch=master)](https://coveralls.io/github/tulibraries/cob_index?branch=master)

Cob Index is a repository to hold the traject configuration files and scripts
associated with indexing of the tul_cob books catalog.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'cob_index'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install cob_index

## Usage

### ingest

`cob_index` is an executable.  You can use it to ingest files into SOLR_URL with

```
cob_index ingest $path_to_file
```

`$path_file` can also be a URL.


#### Ingest switches
`--commit` If this switch is passed (`cob_index ingest --commit`), then cob_index will send commit at end of ingest process.

### deletes

```
cob_index delete  $path_to_file
```

### harvest

```
cob_index harvest  --type=alma-electronic
```

Runs pre defined harvesting endpoints for tul_cob. Note the only type currently defined is for the alma-electronic api and thus it is set by default.

#### Harvest endpoint types
##### alma-electronic
`collection_notes.json` and `service_notes.json` files get outputed to the working directory when `cob_index harvest --type=alma-electronic` is run.

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/tulibraries/cob_index. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [Contributor Covenant](http://contributor-covenant.org) code of conduct.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the CobIndex project’s codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/tulibraries/cob_index/blob/master/CODE_OF_CONDUCT.md).
