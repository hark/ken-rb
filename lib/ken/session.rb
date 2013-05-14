module Ken
  class << self
    attr_accessor :session
  end

  # A class for returing errors from the freebase api.
  # For more infomation see the freebase documentation:
  class ReadError < ArgumentError
    attr_accessor :code, :msg
    def initialize(code,msg)
      self.code = code
      self.msg = msg
    end
    def message
      "#{code}: #{msg}"
    end
  end

  class AttributeNotFound < StandardError ; end
  class PropertyNotFound < StandardError ; end
  class ResourceNotFound < StandardError ; end
  class TopicNotFound < StandardError ; end
  class ViewNotFound < StandardError ; end

  # partially taken from chris eppstein's freebase api
  # http://github.com/chriseppstein/freebase/tree
  class Session
    attr_reader :host, :key

    # Initialize a new Ken Session
    #   Ken::Session.new(host{String, IO}, key{String})
    #
    # @param host<String>          the API host
    # @param key<String>           google api key
    def initialize(host, key = nil)
      @host = host
      @key = key

      Ken.session = self

      # TODO: check connection
      Ken.logger.info("connection established.")
    end

    SERVICES = {
      :mqlread => '/mqlread',
      :mqlwrite => '/mqlwrite',
      :topic => '/topic',
      :search => '/search',
      :rdf => '/rdf',
    }

    # get the service url for the specified service.
    def service_url(svc)
      "#{@host}#{SERVICES[svc]}"
    end

    SERVICES.each_key do |k|
      define_method("#{k}_service_url") do
        service_url(k)
      end
    end

    # raise an error if the inner response envelope is encoded as an error
    def handle_read_error(inner)
      if inner['error']
        error = inner['error']
        Ken.logger.error "Read Error #{error.inspect}"
        raise ReadError.new(error['code'], error['message'])
      end
    end # handle_read_error

    # Perform a mqlread and return the results
    # Specify :cursor => true to batch the results of a query, sending multiple requests if necessary.
    # TODO: should support multiple queries
    #       you should be able to pass an array of queries
    def mqlread(query, options = {})
      Ken.logger.info ">>> Sending Query: #{query.to_json}"
      cursor = options[:cursor]
      if cursor
        query_result = []
        while cursor
          response = get_query_response(query, cursor)
          query_result += response['result']
          cursor = response['cursor']
        end
      else
        response = get_query_response(query)
        query_result = response['result']
      end
      query_result
    end

    def topic(id, options = {})
      response = http_request topic_service_url + id, options
      result = JSON.parse response
      handle_read_error(result)
      Ken.logger.info "<<< Received Topic Response: #{result.inspect}"
      result
    end

    def search(query, options = {})
      Ken.logger.info ">>> Sending Search Query: #{query}"
      options.merge!({:query => query})

      response = http_request search_service_url, options
      result = JSON.parse response

      handle_read_error(result)

      Ken.logger.info "<<< Received Topic Response: #{result['result'].inspect}"
      result['result']
    end

    protected

    # returns parsed json response from freebase mqlread service
    def get_query_response(query, cursor=nil)
      params = {
        :query => query.to_json,
        :html_escape => false,
      }

      if cursor
        params[:cursor] = (cursor == true) ? "" : cursor
      end

      response = http_request mqlread_service_url, params
      result = JSON.parse response
      handle_read_error(result)
      Ken.logger.info "<<< Received Response: #{result['result'].inspect}"
      result
    end

    # encode parameters
    def params_to_string(parameters)
      parameters.keys.map {|k| "#{URI.encode(k.to_s)}=#{URI.encode(parameters[k].to_s)}" }.join('&')
    end

    # does the dirty work
    def http_request(url, parameters = {})
      parameters[:key] = key if !key.nil?
      param_string = params_to_string(parameters)

      url << '?'+param_string unless param_string !~ /\S/
      Ken.logger.info "<<< URL queried: #{url}"

      uri = URI.parse(url)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      http.verify_mode = OpenSSL::SSL::VERIFY_NONE

      request = Net::HTTP::Get.new(uri.request_uri)

      response = http.request(request)

      return response.body
    end
  end # class Session
end # module Ken
