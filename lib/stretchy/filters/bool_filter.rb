module Search
  module Filters
    class BoolFilter
      def initialize(must:, must_not:, should: nil)
        @must     = Array(must)
        @must_not = Array(must_not)
        @should   = Array(should)
      end

      def to_search
        json = {}
        json[:must]     = @must.map(&:to_search) if @must.present?
        json[:must_not] = @must_not.map(&:to_search) if @must_not.present?
        json[:should]   = @should.map(&:to_search) if @should.present?
        { bool: json }
      end
    end
  end
end
