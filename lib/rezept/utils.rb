require 'json'
require 'diffy'
require 'coderay'

module Rezept
  class Utils

    def self.diff(converter, hash1, hash2)
      Diffy::Diff.new(
        converter.to_dsl(hash1),
        converter.to_dsl(hash2),
        :diff => '-u'
      ).to_s(:color)
    end

    def self.print_ruby(ruby, color=false)
      if color
        puts CodeRay.scan(ruby, :ruby).terminal
      else
        puts ruby
      end
    end

    def self.print_json(json, color=false)
      if color
        puts CodeRay.scan(json, :json).terminal
      else
        puts json
      end
    end
  end
end
