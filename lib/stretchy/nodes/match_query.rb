require 'stretchy/nodes/base'

module Stretchy
  module Nodes
    class MatchQuery < Base

      OPERATORS   = ['and', 'or']
      MATCH_TYPES = ['phrase', 'phrase_prefix']

      attribute :field,     String, default: '_all'
      attribute :string,    Array[String]
      attribute :operator,  String
      attribute :type,      String
      attribute :slop,      Integer
      attribute :min,       Integer
      attribute :max,       Float

      validations do
        rule :field,     field:     { required: true }
        rule :string,    type:      {classes: String, array: true}
        rule :string,    :required
        rule :operator,  inclusion: {in: OPERATORS}
        rule :type,      inclusion: {in: MATCH_TYPES}
        rule :slop,      type:      Numeric
        rule :max,       type:      Numeric
        rule :min,       :min_should_match
      end

      def node_type
        :query
      end

      def after_initialize(params)
        @min    ||= params[:minimum_should_match]
        @string ||= params[:query]
      end

      def option_attributes
        return @opts if @opts
        @opts = {}
        @opts[:query]                = @string.join(' ')
        @opts[:type]                 = @type       if @type
        @opts[:operator]             = @operator   if @operator
        @opts[:minimum_should_match] = @min        if @min
        @opts[:slop]                 = @slop       if @slop && MATCH_TYPES.include?(@type)
        @opts[:max_expansions]       = @max        if @max && @type == 'phrase_prefix'
        @opts
      end

      def to_search
        {
          match: {
            @field => option_attributes,
          }
        }
      end

      def add_query(node, options = {})
        if node.is_a?(self.class) && node.field == field
          @string += Array(node.string)
          @string = @string.compact.uniq
          self
        else
          replace_node(self, BoolQuery.new(
            must: [self, node]
          ))
        end
      end

      def add_filter(node, options = {})
        replace_node(self, FilteredQuery.new(
          query: self,
          filter: node
        ))
      end

    end
  end
end
