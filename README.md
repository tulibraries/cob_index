# TUL catalog indexing (cob_index)
[![Build Status](https://travis-ci.org/tulibraries/cob_index.svg?branch=main)](https://travis-ci.org/tulibraries/cob_index)
[![Coverage Status](https://coveralls.io/repos/github/tulibraries/cob_index/badge.svg?branch=main)](https://coveralls.io/github/tulibraries/cob_index?branch=main)

**cob_index** is a repository that holds the [Traject](https://github.com/traject/traject) configuration files and scripts
associated with the customized MARCXML-Solr metadata transformations and indexing for Temple University Libraries' Library Search ([tul_cob](https://github.com/tulibraries/tul_cob)).

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

#### Ingest ENV variables
`ALMAOAI_LAST_HARVEST_FROM_DATE`: if provided used as one of the possible defaults for `extract_update_date` macro.

`SOLR_DISABLE_UPDATE_DATE_CHECK`: When set to "yes" will make `extract_update_date` macro use `Time.now.utc.to_s` effectively overriding date versioning on Solr instance.


### deletes

```
cob_index delete  $path_to_file
```
#### Ingest switches
`--commit` If this switch is passed (`cob_index delete --commit`), then
cob_index will send commit at end of delete process.

`--suppress` If this switch is passed (`cob_index delete --suppress`), then
instead of outright deleting the documents we enable a suppression field which
we filter out at query time.


### harvest

```
cob_index harvest  --type=alma-electronic
```

Runs pre defined harvesting endpoints for tul_cob. Note the only type currently defined is for the alma-electronic api and thus it is set by default.

### commit

```
cob_index commit
```

Sends a commit command to the Solr instance.

#### Harvest endpoint types
##### alma-electronic
`collection_notes.json` and `service_notes.json` files get outputed to the working directory when `cob_index harvest --type=alma-electronic` is run.

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

To run the executable without installing, run `bundle exec cob_index`.

### Spot reindexing workflow

Sometimes it may be convenient to reindex a particular record in the production / qa Solr index to allow an acceptance tester to proceed
without requiring a full reindex. In that case, a workflow like the following example can be used:

```sh
# set up some env vars to make this easy
export SOLR_URL_PROD="https://$SOLRCLOUD_USER:$SOLRCLOUD_PASSWORD@$SOLRCLOUD_HOST/solr/$CATALOG_COLLECTION"
export SOLR_DISABLE_UPDATE_DATE_CHECK=true
export ID=99999999999381
SOLR_URL=$SOLR_URL_PROD bundle exec cob_index ingest
 --commit https://librarysearch.temple.edu/catalog/${ID}.xml
```
## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/tulibraries/cob_index. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [Contributor Covenant](http://contributor-covenant.org) code of conduct.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the CobIndex project’s codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/tulibraries/cob_index/blob/main/CODE_OF_CONDUCT.md).
