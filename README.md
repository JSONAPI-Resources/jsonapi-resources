# JSONAPI::Resources [![Gem Version](https://badge.fury.io/rb/jsonapi-resources.svg)](https://badge.fury.io/rb/jsonapi-resources) [![Build Status](https://secure.travis-ci.org/cerebris/jsonapi-resources.svg?branch=master)](http://travis-ci.org/cerebris/jsonapi-resources) [![Code Climate](https://codeclimate.com/github/cerebris/jsonapi-resources/badges/gpa.svg)](https://codeclimate.com/github/cerebris/jsonapi-resources)

[![Join the chat at https://gitter.im/cerebris/jsonapi-resources](https://badges.gitter.im/Join%20Chat.svg)](https://gitter.im/cerebris/jsonapi-resources?utm_source=badge&utm_medium=badge&utm_campaign=pr-badge&utm_content=badge)

`JSONAPI::Resources`, or "JR", provides a framework for developing an API server that complies with the
[JSON:API](http://jsonapi.org/) specification.

Like JSON:API itself, JR's design is focused on the resources served by an API. JR needs little more than a definition
of your resources, including their attributes and relationships, to make your server compliant with JSON API.

JR is designed to work with Rails 5.1+, and provides custom routes, controllers, and serializers. JR's resources may be
backed by ActiveRecord models or by custom objects.

## Documentation

Full documentation can be found at [http://jsonapi-resources.com](http://jsonapi-resources.com), including the [v0.10 alpha Guide](http://jsonapi-resources.com/v0.10/guide/) specific to this version. 

## Demo App

We have a simple demo app, called [Peeps](https://github.com/cerebris/peeps), available to show how JR is used.

## Client Libraries

JSON:API maintains a (non-verified) listing of [client libraries](http://jsonapi.org/implementations/#client-libraries)
which *should* be compatible with JSON:API compliant server implementations such as JR.

## Installation

Add JR to your application's `Gemfile`:

``` 
gem 'jsonapi-resources'
```

And then execute:

```bash 
bundle
```

Or install it yourself as:

```bash 
gem install jsonapi-resources
```

**For further usage see the [v0.10 alpha Guide](http://jsonapi-resources.com/v0.10/guide/)**

## Development

There is a docker compose setup that can be used for testing your code against the supported versions of ruby and
against PostgreSQL, MYSQL, and SQLite databases.

First build the docker image:
```bash
docker compose build
```
Be sure to rebuild after making code changes. It should be fast after the initial build.

### Running the tests

The default command will run everything (it may take a while):
```bash
docker compose run tests
```

To test just one database against the latest ruby:
```bash
docker compose run tests ./test_mysql
docker compose run tests ./test_postgresql
docker compose run tests ./test_sqlite
```

To test a version of ruby against all databases:
```bash
docker compose run tests ./test_ruby 2.7.7
```

The tests by default run against the latest rails version. To override that you can set the RAILS_VERSION environment
variable:

```bash
docker compose run -e RAILS_VERSION=6.1.1 tests ./test_postgresql
```

## Contributing

1. Submit an issue describing any new features you wish it add or the bug you intend to fix
1. Fork it ( http://github.com/cerebris/jsonapi-resources/fork )
1. Create your feature branch (`git checkout -b my-new-feature`)
1. Run the full test suite (`rake test`)
1. Fix any failing tests
1. Commit your changes (`git commit -am 'Add some feature'`)
1. Push to the branch (`git push origin my-new-feature`)
1. Create a new Pull Request

## Did you find a bug?

* **Ensure the bug was not already reported** by searching on GitHub under [Issues](https://github.com/cerebris/jsonapi-resources/issues).

* If you're unable to find an open issue addressing the problem, [open a new one](https://github.com/cerebris/jsonapi-resources/issues/new). 
Be sure to include a **title and clear description**, as much relevant information as possible, 
and a **code sample** or an **executable test case** demonstrating the expected behavior that is not occurring.

* If possible, use the relevant bug report templates to create the issue. 
Simply copy the content of the appropriate template into a .rb file, make the necessary changes to demonstrate the issue, 
and **paste the content into the issue description or attach as a file**:
  * [**Rails 5** issues](https://github.com/cerebris/jsonapi-resources/blob/master/lib/bug_report_templates/rails_5_master.rb)


## License

Copyright 2014-2023 Cerebris Corporation. MIT License (see LICENSE for details).
