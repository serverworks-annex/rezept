require 'aws-sdk'

module Rezept
  class Client

    def initialize
      @ssm = Aws::SSM::Client.new
      @ec2 = Aws::EC2::Client.new
    end

    def set_options(options)
      @options = options
    end

    def get_documents(next_token = nil)
      docs = []
      list_documents.each do |doc|
        doc = doc.to_h
        doc['content'] = @ssm.get_document(
          name: doc[:name], document_version: doc[:document_version]).content
        doc.merge!(@ssm.describe_document_permission(name: doc[:name], permission_type: 'Share').to_h)
        doc = Hash[ doc.to_h.map{|k,v| [k.to_s, v] } ]
        docs << doc
      end
      docs
    end

    def list_documents(next_token = nil)
      opt = {}
      opt[:max_results] = 50
      opt[:next_token] = next_token unless next_token.nil?

      ret = @ssm.list_documents(opt)
      ret.document_identifiers.concat(list_docs(ret.next_token)) unless ret.next_token.nil?
      ret.document_identifiers.reject{|d| d.owner == 'Amazon' and not @options['amazon_docs'] }
    end

    def create_document(doc)
      @ssm.create_document(
        name: doc['name'], document_type: doc['document_type'], content: doc['content'])
    end

    def version_up_document(doc)
      @ssm.update_document_default_version(
        name: doc['name'],
        document_version: @ssm.update_document(
          name: doc['name'], content: doc['content'], document_version: '$LATEST'
        ).document_description.document_version
      )
    end

    def delete_document(doc)
      @ssm.delete_document(name: doc['name'])
    end

    def modify_document_permission(doc, add_ids, rm_ids)
      @ssm.modify_document_permission(
        name: doc['name'],
        permission_type: 'Share',
        account_ids_to_add: add_ids,
        account_ids_to_remove: rm_ids
      )
    end

    def get_instances(instance_ids=nil, filters=nil, next_token=nil)
      instances = []

      ret = @ec2.describe_instances(
        instance_ids: instance_ids,
        filters: filters,
        next_token: next_token
      )
      ret.reservations.each do |reservation|
        instances.concat(reservation.instances)
      end

      instances.concat(get_instances(instance_ids, filters, ret.next_token)) unless ret.next_token.nil?
      instances
    end

    def get_managed_instances(instance_ids, next_token=nil)
      instances = []

      ret = @ssm.describe_instance_information(
        filters: [{
          key: "InstanceIds",
          values: instance_ids
        }],
        next_token: next_token
      )
      instances = ret.instance_information_list
      instances.concat(get_target_instances(instance_ids, ret.next_token)) unless ret.next_token.nil?
      instances
    end

    def run_command(name, instance_ids, targets, parameters)
      @ssm.send_command(
        document_name: name,
        instance_ids: instance_ids,
        targets: targets,
        parameters: parameters
      ).command
    end

    def list_command_invocations(command_id, next_token=nil)
      ret = @ssm.list_command_invocations(command_id: command_id)
      invocations = ret.command_invocations
      invocations.concat(list_command_invocations(command_id, ret.next_token)) unless ret.next_token.nil?
      invocations
    end

    def put_inventory(instance_id, type_name, schema_version, content)
      @ssm.put_inventory(
        instance_id: instance_id,
        items: [
          {
            type_name: type_name,
            schema_version: schema_version,
            capture_time: Time.now.strftime('%Y-%m-%dT%H:%M:%SZ'),
            content: [content],
          },
        ],
      )
    end

    def list_inventory_entries(instance_id, type_name, filters)
      @ssm.list_inventory_entries(
        instance_id: instance_id,
        type_name: type_name,
        filters: filters,
      )
    end

  end
end
