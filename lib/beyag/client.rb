require 'logger'
require 'ostruct'

module Beyag
  class Client
    attr_reader :shop_id, :secret_key, :gateway_url, :opts
    cattr_accessor :proxy

    def initialize(params)
      @shop_id = params.fetch(:shop_id)
      @secret_key = params.fetch(:secret_key)
      @gateway_url = params.fetch(:gateway_url)
      @opts = params[:options] || {}
    end

    def query(order_id)
      build_response get("/payments/#{order_id}")
    end

    def erip_payment(params)
      build_response post('/payments', request: params)
    end

    def bank_list(gateway_id)
      build_response get("/gateways/#{gateway_id}/bank_list")
    end

    %i[payment refund payout].each do |method|
      define_method(method) do |params|
        build_response post("/transactions/#{method}", request: params)
      end
    end

    private

    attr_reader :response

    DEFAULT_OPEN_TIMEOUT = 5
    DEFAULT_TIMEOUT = 25

    def request
      begin
        yield
      rescue Exception => e
        logger = Logger.new(STDOUT)
        logger.error("Error: #{e.message}\nTrace:\n#{e.backtrace.join("\n")}")
        OpenStruct.new(status: 422)
      end
    end

    def connection
      @connection ||= Faraday::Connection.new(opts) do |c|
        c.options[:open_timeout] ||= DEFAULT_OPEN_TIMEOUT
        c.options[:timeout] ||= DEFAULT_TIMEOUT
        c.options[:proxy] = proxy if proxy
        c.request :json

        c.headers = {'Content-Type' => 'application/json'}.update(opts[:headers].to_h)

        c.basic_auth(shop_id, secret_key)
        c.adapter Faraday.default_adapter
      end
    end

    def build_response(response)
      Response.new(response)
    end

    def post(path, data = {})
      request { connection.post(full_path(path), data.to_json) }
    end

    def get(path)
      request { connection.get full_path(path) }
    end

    def full_path(path)
      [gateway_url, path].join
    end
  end
end
