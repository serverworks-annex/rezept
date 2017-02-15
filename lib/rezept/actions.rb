require 'yaml'
require 'json'

module Rezept
  class Actions
    include Rezept::Logger::Helper

    def initialize(client, converter)
      @client = client
      @converter = converter
    end

    def export(options)
      @converter.set_options(options)
      @client.set_options(options)
      docs = @client.get_documents

      if options['write']
        if options['split']
          content = ''
          docs.each do |doc|
            name = @converter.filename(doc.name)
            _export_dsl_file(@converter.to_dsl(doc), "#{name}.rb")
            content << "require #{name.inspect}\n"
          end
          _export_dsl_file(content, options['file'])
        else
          _export_dsl_file(@converter.to_dsl_all(docs), options['file'])
        end
      else
        Rezept::Utils.print_ruby(@converter.to_dsl_all(docs), color: options['color'])
      end
    end

    def apply(options)
      @converter.set_options(options)
      @client.set_options(options)
      dry_run = options['dry_run'] ? '[Dry run] ' : ''
      _apply_docs(@converter.dslfile_to_h(options['file']), @client.get_documents, dry_run)
    end

    def convert(options)
      @converter.set_options(options)

      fmt = 'unknown'

      if not options['format'].nil?
        fmt = options['format']
      elsif options['file'] =~ /\.(json|template)$/
        fmt = 'ruby'
      end

      info("Document: '#{options['name']}'")
      info("Document Type: '#{options['type']}'")

      case fmt
      when 'json'
        docs = @converter.dslfile_to_h(options['file'])
        docs = docs.select {|d| d['name'] == options['name'] }
        ret = JSON.pretty_generate(JSON.parse(docs[0]['content']))
        Rezept::Utils.print_json(ret)
      when 'ruby'
        doc = {}
        doc['name'] = options['name']
        doc['document_type'] = options['type']
        doc['content'] = File.read(options['file'])
        ret = @converter.to_dsl(doc)
        Rezept::Utils.print_ruby(ret)
      else
        raise "Unsupported format '#{fmt}'"
      end
      _export_file(ret, options['output']) unless options['output'].nil?
    end

    def _apply_docs(local, remote, dry_run)
      local.each do |l|
        l_ids = l.delete('account_ids')
        r_ids = []
        r = _choice_by_name(remote, l['name'])

        if r.nil?
          info("#{dry_run}Create the new document #{l['name'].inspect}")
          @client.create_document(l) if dry_run.empty?
        else
          r_ids = r.delete('account_ids')
          diff = Rezept::Utils.diff(@converter, r, l)

          if diff == "\n"
            info("#{dry_run}No changes '#{l['name']}'")
          else
            warn("#{dry_run}Update the document #{l['name'].inspect}")
            STDERR.puts diff
            @client.version_up_document(l) if dry_run.empty?
          end
        end

        add_ids = l_ids - r_ids
        del_ids = r_ids - l_ids
        info("#{dry_run}Add permission of #{l['name'].inspect} to #{add_ids.join(', ')}") if add_ids.length > 0
        warn("#{dry_run}Remove permission of #{l['name'].inspect} from #{add_ids.join(', ')}") if del_ids.length > 0
        @client.modify_document_permission(l, add_ids, del_ids) if dry_run.empty?
      end

      remote.each do |r|
        if _choice_by_name(local, r['name']).nil?
          warn("#{dry_run}Delete the document #{r['name'].inspect}")
          @client.delete_document(r) if dry_run.empty?
        end
      end
    end

    def _choice_by_name(docs, name)
      docs.each do |d|
        return d if d['name'] == name
      end
      nil
    end

    def _export_dsl_file(dsl, filenae)
      dsl = <<-EOS
#! /usr/bin/env ruby

#{dsl}
EOS
      _export_file(dsl, filename)
    end

    def _export_file(dsl, filename)
      File.write(filename, dsl)
      info("Write #{filename.inspect}")
    end
  end
end
