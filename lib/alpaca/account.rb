# frozen_string_literal: true

module Alpaca
  class Account
    def initialize(client: Client.new)
      @client = client
    end

    # Full account details (buying power, equity, cash, etc.)
    def info
      @client.trading_get("/v2/account")
    end

    # All open positions
    def positions
      @client.trading_get("/v2/positions")
    end

    # Position for a specific symbol, or nil if none
    def position(symbol)
      @client.trading_get("/v2/positions/#{symbol.upcase}")
    rescue RuntimeError => e
      return nil if e.message.include?("404")
      raise
    end

    def buying_power
      info["buying_power"].to_f
    end

    def equity
      info["equity"].to_f
    end

    def cash
      info["cash"].to_f
    end
  end
end
