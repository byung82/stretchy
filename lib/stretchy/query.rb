module Search
  class Query

    DEFAULT_LIMIT = 40

    def initialize(options = {})
      options = options.with_indifferent_access
      @offset       = options[:offset]      || 0
      @limit        = options[:limit]       || DEFAULT_LIMIT
      @match        = options[:match]
      @filters      = options[:filters]
      @not_filters  = options[:not_filters]
      @boosts       = options[:boosts]
      @type         = options[:type]        || Developer::SEARCH_TYPE
      @index        = options[:index]       || Search::INDEX
      @explain      = options[:explain]
    end

    def clone_with(options)
      options = options.with_indifferent_access

      filters     = [@filters, options[:filters], options[:filter]].flatten.compact
      not_filters = [@not_filters, options[:not_filters], options[:not_filter]].flatten.compact
      boosts      = [@boosts, options[:boosts], options[:boost]].flatten.compact

      self.class.new(
        type:         @type,
        index:        @index,
        explain:      options[:explain] || @explain,
        offset:       options[:offset] || @offset,
        limit:        options[:limit]  || @limit,
        match:        options[:match]  || @match,
        filters:      filters,
        not_filters:  not_filters,
        boosts:       boosts
      )
    end

    def offset(num)
      clone_with(offset: num)
    end

    def limit(num)
      clone_with(limit: num)
    end

    def explain
      clone_with(explain: true)
    end

    def where(options = {})
      return self unless options.present?
      filters, not_filters = where_clause(options)
      clone_with(filters: filters, not_filters: not_filters)
    end

    def not_where(options = {})
      return self unless options.present?
      # reverse the order returned here, since we're doing not_where
      not_filters, filters = where_clause(options)
      clone_with(filters: filters, not_filters: not_filters)
    end

    def boost_where(options = {})
      return self unless options.present?
      weight = options.delete(:weight) || 1.2

      boosts = options.map do |field, values|
        filter = nil
        if values.nil?
          filter = Filters::NotFilter.new(Filters::ExistsFilter.new(field))
        else
          filter = Filters::TermsFilter.new(field: field, values: Array(values))
        end
        Boosts::FilterBoost.new(filter: filter, weight: weight)
      end
      clone_with(boosts: boosts)
    end

    def boost_not_where(options = {})
      return self unless options.present?
      options = options.with_indifferent_access
      weight = options.delete(:weight) || 1.2

      boosts = []
      options.each do |field, values|
        filter = nil
        if values.nil?
          filter = Filters::ExistsFilter.new(field)
        elsif values.is_a?(Array)
          filter = NotFilter.new(Filters::TermsFilter.new(field: field, values: Array(values)))
        end
        Boosts::FilterBoost.new(filter: filter)
      end
      clone_with(boosts: boosts)
    end

    def range(field:, min: nil, max: nil)
      return self unless min.present? || max.present?
      clone_with(filter: Filters::RangeFilter.new(
        field: field,
        min: min,
        max: max
      ))
    end

    def not_range(field:, min: nil, max: nil)
      return self unless min.present? || max.present?
      clone_with(not_filter: Filters::RangeFilter.new(
        field: field,
        min: min,
        max: max
      ))
    end

    def boost_range(field:, min: nil, max: nil, weight: 1.2)
      return self unless min.present? || max.present?
      clone_with(boost: Boosts::Boost.new(
        filter: Filters::RangeFilter.new(
          field: field,
          min: min,
          max: max
        ),
        weight: weight
      ))
    end

    def geo(field: 'coords', distance: '50km', lat:, lng:)
      clone_with(filter: Filters::GeoFilter.new(
        field: field,
        distance: distance,
        lat: lat,
        lng: lng
      ))
    end

    def not_geo(field: 'coords', distance: '50km', lat:, lng:)
      clone_with(not_filter: Filters::GeoFilter.new(
        field: field,
        distance: distance,
        lat: lat,
        lng: lng
      ))
    end

    def boost_geo(options = {})
      return self unless options.present?
      clone_with(boost: Boosts::GeoBoost.new(options))
    end

    def match(string, options = {})
      return self unless string.present?
      field     = options[:field] || '_all'
      operator  = options[:operator] || 'and'
      clone_with(match: Queries::MatchQuery.new(string, field: field, operator: operator))
    end

    def not_match(string, options = {})
      field = options[:field] || '_all'
      operator = options[:operator] || 'and'
      clone_with(not_filter: Filters::QueryFilter.new(
        Queries::MatchQuery.new(string, field: field, operator: operator)
      ))
    end

    def boost_random(seed)
      clone_with(boost: Boosts::RandomBoost.new(seed))
    end

    def request
      @request ||= RequestBody.new(
        match:        @match,
        filters:      @filters,
        not_filters:  @not_filters,
        boosts:       @boosts,
        limit:        @limit,
        offset:       @offset,
        explain:      @explain
      )
    end

    def response
      @response = Search.search(type: @type, body: request.to_search)
      # caution: huuuuge logs, but pretty helpful
      # Rails.logger.debug(Colorize.purple(JSON.pretty_generate(@response)))
      @response
    end

    def id_response
      @id_response ||= Search.search(type: @type, body: request.to_search, fields: [])
      # caution: huuuuge logs, but pretty helpful
      # Rails.logger.debug(Colorize.purple(JSON.pretty_generate(@id_response)))
      @id_response
    end

    def results
      @results ||= response['hits']['hits'].map do |hit|
        hit['_source'].merge(
          '_id' => hit['_id'],
          '_type' => hit['_type'],
          '_index' => hit['_index']
        )
      end
    end

    def ids
      @ids    ||= result_metadata('hits', 'hits').map{ |hit| hit['_id'].to_i == 0 ? hit['_id'] : hit['_id'].to_i }
    end

    def shards
      @shards ||= result_metadata('shards')
    end

    def total
      @total  ||= result_metadata('hits', 'total')
    end

    private
      def result_metadata(*args)
        if @response
          args.reduce(@response){|json, field| json.nil? ? nil : json[field] }
        else
          args.reduce(id_response){|json, field| json.nil? ? nil : json[field] }
        end
      end

      def where_clause(options = {})
        return [[], []] unless options.present?
        options = options.with_indifferent_access
        filters = []
        not_filters = []

        options.each do |field, values|
          if values.nil?
            not_filters << Filters::ExistsFilter.new(field)
          else
            filters << Filters::TermsFilter.new(field: field, values: Array(values))
          end
        end
        [filters, not_filters]
      end

  end
end
