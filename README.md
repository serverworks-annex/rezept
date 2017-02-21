# Rezept

[![Gem Version](https://badge.fury.io/rb/rezept.svg)](https://badge.fury.io/rb/rezept)

A tool to manage EC2 Systems Manager (SSM) Documents with programmable DSL.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'rezept'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install rezept

## Usage

#### General

```
$ rezept
Commands:
  rezept apply                                    # Apply the documents
  rezept convert -n, --name=NAME -t, --type=TYPE  # Convert the documents to the other format
  rezept export                                   # Export the documents
  rezept help [COMMAND]                           # Describe available commands or one specific command

Options:
  -f, [--file=FILE]                        # Configuration file
                                           # Default: Docfile
      [--color], [--no-color]              # Disable colorize
                                           # Default: true
      [--amazon-docs], [--no-amazon-docs]  # Include Amazon owned documents
      [--dsl-content], [--no-dsl-content]  # Convert JSON contents to DSL
                                           # Default: true
```

#### apply
Apply the documents

```
$ rezept help apply
Usage:
  rezept apply

Options:
      [--dry-run], [--no-dry-run]          # Dry run (Only output the difference)
  -f, [--file=FILE]                        # Configuration file
                                           # Default: Docfile
      [--color], [--no-color]              # Disable colorize
                                           # Default: true
      [--amazon-docs], [--no-amazon-docs]  # Include Amazon owned documents
      [--dsl-content], [--no-dsl-content]  # Convert JSON contents to DSL
                                           # Default: true
```

#### convert
Convert the documents to the other format

```
$ rezept help convert
Usage:
  rezept convert -n, --name=NAME -t, --type=TYPE

Options:
  -n, --name=NAME                          # Name of document
  -t, --type=TYPE                          # Type of document (Command|Automation)
      [--format=FORMAT]                    # Output format (json|ruby)
  -o, [--output=OUTPUT]                    # Output filename (path)
  -f, [--file=FILE]                        # Configuration file
                                           # Default: Docfile
      [--color], [--no-color]              # Disable colorize
                                           # Default: true
      [--amazon-docs], [--no-amazon-docs]  # Include Amazon owned documents
      [--dsl-content], [--no-dsl-content]  # Convert JSON contents to DSL
                                           # Default: true
```

#### export
Export the documents

```
$ rezept help export
Usage:
  rezept export

Options:
      [--write], [--no-write]              # Write the documents to the file
      [--split], [--no-split]              # Split file by the documents
  -f, [--file=FILE]                        # Configuration file
                                           # Default: Docfile
      [--color], [--no-color]              # Disable colorize
                                           # Default: true
      [--amazon-docs], [--no-amazon-docs]  # Include Amazon owned documents
      [--dsl-content], [--no-dsl-content]  # Convert JSON contents to DSL
                                           # Default: true
```

#### run_command
Run the commands

```
$ rezept help run_command
Usage:
  rezept run_command -n, --name=NAME

Options:
  -n, --name=NAME                          # Name of the document
  -i, [--instance-ids=one two three]       # EC2 Instance IDs
  -t, [--tags=key:value]                   # EC2 Instance tags
  -p, [--parameters=key:value]             # Parameters for the document
      [--dry-run], [--no-dry-run]          # Dry run (Only output the targets)
      [--wait], [--no-wait]                # Wait and check for all results
  -f, [--file=FILE]                        # Configuration file
                                           # Default: Docfile
      [--color], [--no-color]              # Disable colorize
                                           # Default: true
      [--amazon-docs], [--no-amazon-docs]  # Include Amazon owned documents
      [--dsl-content], [--no-dsl-content]  # Convert JSON contents to DSL
                                           # Default: true
```

- If you specify multiple values to `tags` and `parameters`, separate them with commas(`,`).
- When you use the `wait` option, the exit code will be `0` if the commands succeed on the all instances, else it will be `1`.

## Advanced methods

#### Script styled commands (__script)

- Docfile

```
Command "My-RunShellScript" do
  account_ids []
  content do
    __dsl do
      schemaVersion "2.0"
      description "my Run a shell script or specify the path to a script to run."
      mainSteps do |*|
        action "aws:runShellScript"
        name "runShellScript"
        inputs do
          runCommand __script(<<-'EOS')
#! /bin/bash
echo 1
echo 2
echo 3
EOS
        end
      end
    end
  end
end
```

- Result

```sh
$ rezept convert -n My-RunShellScript -t Command --format json
Document: 'My-RunShellScript'
Document Type: 'Command'
{
  "schemaVersion": "2.0",
  "description": "Run a shell script",
  "mainSteps": [
    {
      "action": "aws:runShellScript",
      "name": "runShellScript",
      "inputs": {
        "runCommand": [
          "#! /bin/bash",
          "echo 1",
          "echo 2",
          "echo 3"
        ]
      }
    }
  ]
}
```

#### Commands from the other script file (__script_file)

- Docfile

```
Command "My-RunShellScript" do
  account_ids []
  content do
    __dsl do
      schemaVersion "2.0"
      description "my Run a shell script or specify the path to a script to run."
      mainSteps do |*|
        action "aws:runShellScript"
        name "runShellScript"
        inputs do
          runCommand __script_file("script.sh")
        end
      end
    end
  end
end
```

- script.sh

```sh
#! /bin/bash
echo 1
echo 2
echo 3
```

- Result

```sh
$ rezept convert -n My-RunShellScript -t Command --format json
Document: 'My-RunShellScript'
Document Type: 'Command'
{
  "schemaVersion": "2.0",
  "description": "Run a shell script",
  "mainSteps": [
    {
      "action": "aws:runShellScript",
      "name": "runShellScript",
      "inputs": {
        "runCommand": [
          "#! /bin/bash",
          "echo 1",
          "echo 2",
          "echo 3"
        ]
      }
    }
  ]
}
```

#### Templating

- Docfile

```ruby
template "runShellScriptTemplate" do
  content do
    __dsl do
      schemaVersion "2.0"
      description "Run a shell script"
      mainSteps do |*|
        action "aws:runShellScript"
        name "runShellScript"
        inputs do
          runCommand __script(context.commands)
        end
      end
    end
  end
end

Command "My-RunShellScript" do
  account_ids []
  include_template "runShellScriptTemplate", commands: "echo 1"
end
```

- Result

```sh
$ rezept convert -n My-RunShellScript -t Command --format json
Document: 'My-RunShellScript'
Document Type: 'Command'
{
  "schemaVersion": "2.0",
  "description": "Run a shell script",
  "mainSteps": [
    {
      "action": "aws:runShellScript",
      "name": "runShellScript",
      "inputs": {
        "runCommand": [
          "echo 1"
        ]
      }
    }
  ]
}
```

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/serverworks/rezept. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [Contributor Covenant](http://contributor-covenant.org) code of conduct.


## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).
