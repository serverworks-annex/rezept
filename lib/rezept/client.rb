require 'aws-sdk'

module Rezept
  class Client

    def initialize
      @ssm = Aws::SSM::Client.new
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
        account_ids_to_remove: rm_ids)
    end

  end
end
