require 'thor'

module Rezept
  class Cli < Thor
    class_option :file, aliases: '-f', desc: 'Configuration file', type: :string, default: 'Docfile'
    class_option :color, desc: 'Disable colorize', type: :boolean, default: $stdout.tty?
    class_option :amazon_docs, desc: 'Include Amazon owned documents', type: :boolean, default: false
    class_option :dsl_content, desc: 'Convert JSON contents to DSL', type: :boolean, default: true

    def initialize(*args)
      @actions = Rezept::Actions.new(
        Rezept::Client.new,
        Rezept::Converter.new
      )
      super(*args)
    end

    desc "export", "Export the documents"
    option :write, desc: 'Write the documents to the file', type: :boolean, default: false
    option :split, desc: 'Split file by the documents', type: :boolean, default: false
    def export
      @actions.export(options)
    end

    desc "apply", "Apply the documents"
    option :dry_run, desc: 'Dry run (Only output the difference)', type: :boolean, default: false
    def apply
      @actions.apply(options)
    end

    desc "convert", "Convert the documents to the other format"
    option :name, aliases: '-n', desc: 'Name of document', type: :string, required: true
    option :type, aliases: '-t', desc: 'Type of document (Command|Automation)', type: :string, required: true
    option :format, desc: 'Output format (json|ruby)', type: :string
    option :output, aliases: '-o', desc: 'Output filename (path)', type: :string
    def convert
      @actions.convert(options)
    end
  end
end
