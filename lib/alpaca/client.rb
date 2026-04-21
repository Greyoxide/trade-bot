# frozen_string_literal: true

require "faraday"
require "json"

module Alpaca
  class Client
    TRADING_BASE_URL = "https://api.alpaca.markets".freeze
    DATA_BASE_URL    = "https://data.alpaca.markets".freeze

    def initialize(
      api_key:    ENV.fetch("ALPACA_API_KEY"),
      api_secret: ENV.fetch("ALPACA_API_SECRET"),
      paper:      ENV.fetch("ALPACA_PAPER", "true") == "true"
    )
      @api_key    = api_key
      @api_secret = api_secret
      base_url    = paper ? "https://paper-api.alpaca.markets" : TRADING_BASE_URL
      @trading    = build_connection(base_url)
      @data       = build_connection(DATA_BASE_URL)
    end

    def trading_get(path, params = {})
      response = @trading.get(path, params)
      parse!(response)
    end

    def trading_post(path, body = {})
      response = @trading.post(path) do |req|
        req.headers["Content-Type"] = "application/json"
        req.body = body.to_json
      end
      parse!(response)
    end

    def trading_delete(path, params = {})
      response = @trading.delete(path, params)
      parse!(response)
    end

    def data_get(path, params = {})
      response = @data.get(path, params)
      parse!(response)
    end

    private

    def build_connection(base_url)
      Faraday.new(url: base_url) do |f|
        f.headers["APCA-API-KEY-ID"]     = @api_key
        f.headers["APCA-API-SECRET-KEY"] = @api_secret
        f.headers["Accept"]              = "application/json"
        f.adapter Faraday.default_adapter
      end
    end

    def parse!(response)
      raise "Alpaca API error #{response.status}: #{response.body}" unless response.success?

      body = response.body
      return nil if body.nil? || body.empty?

      JSON.parse(body)
    end
  end
end
