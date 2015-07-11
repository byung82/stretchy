module Stretchy
  module Utils

    module_function

    # stolen straight from ActiveSupport
    def underscore(camel_cased_word)
      word = camel_cased_word.to_s.gsub('::', '/')
      word.gsub!(/(?:([A-Za-z\d])|^)(#{inflections.acronym_regex})(?=\b|[^a-z])/) { "#{$1}#{$1 && '_'}#{$2.downcase}" }
      word.gsub!(/([A-Z\d]+)([A-Z][a-z])/,'\1_\2')
      word.gsub!(/([a-z\d])([A-Z])/,'\1_\2')
      word.tr!("-", "_")
      word.downcase!
      word
    end

    def base_class_name(obj)
      obj.class.name.split(/::/).last
    end

    def is_empty?(val)
      val.nil? || (val.respond_to?(:empty?) && val.empty?)
    end

    def present?(val)
      !is_empty?(val)
    end

  end
end

require 'stretchy/utils/validation'
require 'stretchy/utils/colorize'
require 'stretchy/utils/logger'
require 'stretchy/utils/dot_handler'
require 'stretchy/utils/configuration'
require 'stretchy/utils/client_actions'
