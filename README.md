# Jupyter

Welcome to your new gem! In this directory, you'll find the files you need to be able to package up your Ruby library into a gem. Put your Ruby code in the file `lib/jupyter`. To experiment with that code, run `bin/console` for an interactive prompt.

TODO: Delete this and the text above, and describe your gem

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'jupyter'
```

And then execute:

    $ bundle


## Usage

Jupyter is just a wrapper to let us control jmeter and integrate with AWS easier. It still uses jmeter-ruby's DSL to write the test plan

### Generate your test Plan

(TODO):

You can use jupyter to generate templated plan

ex:

> jupyter generate plan user_login

the test plans is generated under directory ./plan


### Write Test PLan

Write you test plan with DSL of jmeter-ruby (https://github.com/flood-io/ruby-jmeter)

ex:

```
test do
  threads Jupyter.threads_settings do
    loop_controller Jupyter.loop_controller_settings do
      visit name: 'Google Search', url: 'http://google.com'
    end
  end
end
```

Or you can write your own class to encapsulate your business logic, ex:

```
require 'gravity_chamber'

test do
  threads Jupyter.threads_settings do
    loop_controller Jupyter.loop_controller_settings do
      chamber = GravityChamber.new(self)
      chamber.standard_login!
      chamber.draw_gasha!
      chamber.accept_apologies!
      chamber.accept_login_bonus!
    end
  end
end
```

### Run the test with Jupyter

> bundle exec jupyter [stage] [--options]

ex:

bundle exec jupyter preview --remote --output csv

The default stage is `development`

It support following options:

- file: specify the test plan file to execute. Default is `default.rb`
- remote: run jupyter with master-slave, it get slaves servers via AWS SDK(TODO)
- output: specify output format, the default is print out as json, it supports csv(TODO), table and sqs
- log: specify the name of log file, which should be placed under ./log directory
- cloudwatch-delay: delayed seconds the execute query for get server stats from cloudwatch.

e.g.:

> bundle exec jupyter staging --remote --output table --log my.log --cloudwatch-delay 60

And You can control JMeter threads setting via following options

- threads: The threads count
- rampup: The rampup seconds
- loops: Loops amount of the loop controller


e.g.:

> bundle exec jupyter staging --remote --threads 150 --loops 5 --rampup 50


### Send Output to AWS SQS

Setup queue name in jupyter.yml, e.g.:

```
development:
  aws:
    sqs:
      queue_name: 'my-sqs-queue-name'
```

Specify output with `sqs` when running jupyter

```
jupyter --remote --output sqs
```


## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/[USERNAME]/jupyter.

