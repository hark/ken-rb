module Ken
  class Type

    include Extlib::Assertions

    # initializes a resource using a json result
    def initialize(data)
      assert_kind_of 'data', data, Hash
      @data = data
    end

    # access property info
    # @api public
    def properties
      @properties ||= Ken::Collection.new(@data["properties"].map { |property| Ken::Property.new(property, self) })
    end

    # type id
    # @api public
    def id
      @data["id"]
    end

    # type name
    # @api public
    def name
      @data["name"]
    end

    # @api public
    def to_s
      name || id || ""
    end

    # @api public
    def inspect
      result = "#<Type id=\"#{id}\" name=\"#{name || "nil"}\">"
    end

    # delegate to property_get
    def method_missing sym
      property_get(sym.to_s)
    end

    private
    # @api private
    # search for a property by name and return it
    def property_get(name)
      properties.each { |p| return p if p.id =~ /\/#{name}$/ }
      raise PropertyNotFound
    end
  end
end
