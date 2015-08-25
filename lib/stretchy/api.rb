require 'stretchy/utils'

module Stretchy
  class API
    DEFAULT_BOOST     = 2.0
    DEFAULT_PER_PAGE  = 10

    extend  Forwardable
    include Enumerable
    include Utils::Methods

    delegate [:total, :ids, :scores, :explanations, :results,
              :aggregations, :first, :last, :each] => :results

    attr_reader :collector, :root, :context

    def initialize(options = {})
      @collector  = AndCollector.new(options[:nodes] || [], query: true)
      @root       = options[:root]     || {}
      @context    = options[:context]  || {}
    end

    def context?(*args)
      (args - context.keys).empty?
    end

    def limit(size = nil)
      return @root[:size] || DEFAULT_PER_PAGE unless size
      add_root size: size.to_i
    end
    alias :limit_value :limit

    def offset(from = nil)
      return @root[:from] || 0 unless from
      add_root from: from.to_i
    end

    # page 1 = from: 0, size: per_page
    # page 2 = from: per_page, size: per_page
    def page(num = nil, params = {})
      return current_page if num.nil?
      per_page = params[:limit] || params[:per_page] || limit
      per_page = per_page.to_i > 0 ? per_page : 1
      start    = [num.to_i - 1, 0].max
      add_root from: start * per_page, size: per_page
    end

    def current_page
      current = [offset, 1].max
      current > 1 ? (offset / limit).ceil + 1 : current
    end

    def explain
      add_root explain: true
    end

    def fields(*list)
      add_root fields: list
    end

    def aggs(params = {})
      add_root aggs: params
    end

    def where(params = {})
      add_params params, :filter, :context_nodes
    end

    def match(params = {})
      add_params params, :query, :context_nodes
    end

    def query(params = {})
      add_params params, :query, :raw_node
    end

    def filter(params = {})
      add_params params, :filter, :raw_node
    end

    def should(params = {})
      add_params params, :should, :context_nodes
    end

    def not(params = {})
      add_params params, :must_not, :context_nodes
    end

    def range(params = {})
      require_context!
      add_params params, nil, :range_node
    end

    def geo_distance(params = {})
      add_params params, :filter, :geo_distance_node
    end

    def boost(params = {}, options = {})
      return add_context(:boost) unless params.any?

      subcontext = context.merge(boost: true)
      if params.is_a? self.class
        boost_json = options.merge(filter: params.filter_node.json)
        add_nodes Node.new(boost_json, subcontext)
      else
        add_nodes Factory.raw_boost_node(params, subcontext)
      end
    end

    def field_value(params = {})
      add_params params, :boost, :field_value_function_node
    end

    def random(seed)
      add_params seed, :boost, :random_score_function_node
    end

    def near(params = {})
      add_params params, :boost, :decay_function_node
    end

    def request
      @request ||= begin
        base        = root.dup
        sub         = {query: collector.as_json}
        agg         = base.delete(:aggs) || {}
        sub[:aggs]  = agg if agg.any?

        base.merge(body: sub)
      end
    end

    def response
      @response ||= Stretchy.search(request)
    end

    def results
      @results ||= Results.new request, response
    end

    def method_missing(method, *args, &block)
      if collector.respond_to?(method)
        collector.send(method, *args, &block)
      else
        super
      end
    end

    private

      def require_context!
        return true if context?(:query) || context?(:filter)
        raise 'You must specify either query or filter context'
      end

      def args_to_context(*args)
        args.reduce({}) do |ctx, item|
          next ctx if item.nil?
          item.is_a?(Hash) ? ctx.merge(item) : ctx.merge({item => true})
        end
      end

      def add_params(params = {}, new_context, factory_method)
        return add_context(new_context) if is_empty?(params)
        subcontext = context.merge(args_to_context(new_context))

        if params.is_a? self.class
          add_nodes params.with_context(subcontext)
        else
          add_nodes Factory.send(factory_method, params, subcontext)
        end
      end

      def add_nodes(additional)
        self.class.new nodes: collector.nodes + Array(additional), root: root
      end

      def add_root(options = {})
        self.class.new(
          nodes:    collector.nodes,
          root:     root.merge(options),
          context:  context
        )
      end

      def add_context(*args)
        self.class.new(
          nodes:   collector.nodes,
          root:    root,
          context: context.merge(args_to_context(*args))
        )
      end

  end
end
