module Stretchy
  module Queries
    class FilteredQuery

      def initialize(query: nil, filter:)
        @query  = query
        @filter = filter
      end

      def to_search
        json = {}
        json[:query]  = @query.to_search  if @query
        json[:filter] = @filter.to_search if @filter
        { filtered: json }
      end
    end
  end
end
