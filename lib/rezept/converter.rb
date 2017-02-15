require 'dslh'

module Rezept
  class Converter

    def set_options(options)
      @options = options
    end

    def to_dsl_all(docs)
      dsls = []
      docs.each do |doc|
        dsls << to_dsl(doc)
      end
      dsls.join("\n")
    end

    def to_dsl(doc)
      exclude_key = proc do |k|
        false
      end

      key_conv = proc do |k|
        k = k.to_s
        if k !~ /\A[_a-z]\w+\Z/i
          "_(#{k.inspect})"
        elsif k == 'runCommand'
          proc do |v, _|
            v = eval("[#{v}]")
            if v.length == 1
              "#{k} #{v.first.inspect}"
            else
              "#{k} __script(<<-'EOS')\n#{v.join("\n")}\nEOS"
            end
          end
        else
          k
        end
      end

      name = doc['name']
      document_type = doc['document_type']

      hash = {}
      hash['account_ids'] = doc['account_ids']
      hash['content'] = doc['content']

      if doc['content'].kind_of?(String)
        if @options['dsl_content']
          hash['content'] = { __dsl: JSON.parse(doc['content']) }
        else
          hash['content'] = doc['content'].gsub(/\R$/, '')
        end
      end

      dsl = Dslh.deval(
        hash,
        exclude_key: exclude_key,
        use_heredoc_for_multi_line: true,
        key_conv: key_conv,
        initial_depth: 1
      )
<<-EOS
#{document_type} #{name.inspect} do
#{dsl}
end
EOS
    end

    def dslfile_to_h(dsl_file)
      context = DSLContext.new
      context.eval_dsl(dsl_file)
    end

    def filename(name)
      name.gsub!(/\W+/, '_')
    end
  end
end
