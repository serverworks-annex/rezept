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

      info("Document: '#{options['document']}'")
      info("Document Type: '#{options['type']}'")

      case fmt
      when 'json'
        docs = @converter.dslfile_to_h(options['file'])
        docs = docs.select {|d| d['name'] == options['document'] }
        ret = JSON.pretty_generate(JSON.parse(docs[0]['content']))
        Rezept::Utils.print_json(ret)
      when 'ruby'
        doc = {}
        doc['name'] = options['document']
        doc['document_type'] = options['type']
        doc['content'] = File.read(options['file'])
        ret = @converter.to_dsl(doc)
        Rezept::Utils.print_ruby(ret)
      else
        raise "Unsupported format '#{fmt}'"
      end
      _export_file(ret, options['output']) unless options['output'].nil?
    end

    def run_command(options)
      dry_run = options['dry_run'] ? '[Dry run] ' : ''
      @client.set_options(options)

      if options['instance_ids'].nil? and options['tags'].nil? and (options['inventory'].nil? or options['conditions'].nil?)
        raise "Please specify the targets (--instance-ids/-i' or '--target-tags/-t' or '--inventroty/-I and --conditions/-C')"
      end

      instances = @client.get_instances(
        options['instance_ids'],
        _tags_to_criteria(options['tags'], 'name')
      )

      instance_ids = []
      instances.each {|i| instance_ids << i.instance_id }
      managed_instances = @client.get_managed_instances(instance_ids)

      if options['wait_entries']
        info("#{dry_run}Wait for entries of managed instances...")
        while instances.length > 0 and managed_instances.length == 0
          sleep 1
          managed_instances = @client.get_managed_instances(instance_ids)
        end
      end

      info("#{dry_run}Target instances...")

      unless options['inventory'].nil?
        managed_instances = _filter_by_inventory(managed_instances, options['inventory'], options['conditions'])
        raise "Can't find target instances from inventories" if managed_instances.empty?
      end
      _print_instances(managed_instances)

      instance_ids = options['instance_ids']
      if instance_ids.nil? and not options['inventory'].nil?
        instance_ids = []
        managed_instances.each {|i| instance_ids << i.instance_id}
      end

      if dry_run.empty?
        command = @client.run_command(
          options['document'],
          instance_ids,
          _tags_to_criteria(options['tags'], 'key'),
          _convert_paraeters(options['parameters'])
        )
        _wait_all_results(command.command_id) if options['wait_results']
      end
    end

    def _filter_by_inventory(instances, inventory, conditions)
      filters = _conditions_to_filters(conditions)
      ret = []
      instances.each do |i|
        inventory_entries = @client.list_inventory_entries(
          i.instance_id,
          inventory,
          filters,
        )
        ret << i unless inventory_entries.entries.empty?
      end
      ret
    end

    def put_inventory(options)
      @client.put_inventory(
        options['instance_id'],
        options['name'],
        options['schema_version'],
        options['content']
      )
    end

    def _print_instances(instances)
      instances.each do |instance|
        if instance.name.nil?
          info("- #{instance.instance_id}")
        else
          info("- #{instance.name} (#{instance.instance_id})")
        end
      end
    end

    def _conditions_to_filters(conditions)
      ret = []
      cond_simbols = {
        '=' => 'Equal',
        '!=' => 'NotEqual',
        '<' =>  'LessThan',
        '>' => 'GreaterThan',
      }
      regexp = /^(?<key>[^=!<>\s]+)\s*(?<type>[=!<>]+)+\s*(?<value>.+)$/

      conditions.each do |c|
        m = regexp.match(c)
        ret << {key: m[:key], values: m[:value].split(','), type: cond_simbols[m[:type]]}
      end
      ret
    end

    def _tags_to_criteria(targets, key_name)
      return nil if targets.nil?
      ret = []
      targets.each {|k,v| ret << {key_name => "tag:#{k}", 'values' => v.split(',')} }
      ret
    end

    def _convert_paraeters(parameters)
      return nil if parameters.nil?
      ret = {}
      parameters.each do |k,v|
        ret[k] = v.split(',')
      end
      ret
    end

    def _wait_all_results(command_id)
      info("Wait for all results...")

      done = false
      failure = false
      done_instances = []

      until done do
        sleep 1
        invocations = @client.list_command_invocations(command_id)
        invocations.each do |invocation|
          break if done_instances.include?(invocation.instance_id)
          unless ['Pending', 'InProgress'].include?(invocation.status)
            case invocation.status
            when 'Success'
              info("- #{invocation.instance_id} => #{invocation.status}")
            when 'Delayed'
              warn("- #{invocation.instance_id} => #{invocation.status}")
            else
              fatal("- #{invocation.instance_id} => #{invocation.status}")
              failure = true
            end
            done_instances << invocation.instance_id
            done = true if done_instances.length == invocations.length
          end
        end
      end

      exit(1) if failure
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

    def _export_dsl_file(dsl, filename)
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
