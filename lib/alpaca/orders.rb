# frozen_string_literal: true

module Alpaca
  class Orders
    def initialize(client: Client.new)
      @client = client
    end

    # Buy by number of shares (market order)
    def buy_shares(symbol, shares)
      place_order(
        symbol:        symbol.upcase,
        qty:           shares.to_s,
        side:          "buy",
        type:          "market",
        time_in_force: "day"
      )
    end

    # Buy by dollar amount (notional market order, fractional shares)
    def buy_dollars(symbol, amount)
      place_order(
        symbol:        symbol.upcase,
        notional:      amount.to_f.round(2).to_s,
        side:          "buy",
        type:          "market",
        time_in_force: "day"
      )
    end

    # Sell by number of shares (market order)
    def sell_shares(symbol, shares)
      place_order(
        symbol:        symbol.upcase,
        qty:           shares.to_s,
        side:          "sell",
        type:          "market",
        time_in_force: "day"
      )
    end

    # Sell by dollar amount (notional market order)
    def sell_dollars(symbol, amount)
      place_order(
        symbol:        symbol.upcase,
        notional:      amount.to_f.round(2).to_s,
        side:          "sell",
        type:          "market",
        time_in_force: "day"
      )
    end

    # Close the entire position for a symbol
    def close_position(symbol)
      @client.trading_delete("/v2/positions/#{symbol.upcase}")
    end

    # Close all open positions
    def close_all_positions(cancel_orders: true)
      @client.trading_delete("/v2/positions", cancel_orders: cancel_orders)
    end

    # List open orders (optionally filter by symbol)
    def list(symbol: nil, status: "open")
      params = { status: status }
      params[:symbols] = symbol.upcase if symbol
      @client.trading_get("/v2/orders", params)
    end

    # Cancel an order by ID
    def cancel(order_id)
      @client.trading_delete("/v2/orders/#{order_id}")
    end

    private

    def place_order(params)
      @client.trading_post("/v2/orders", params)
    end
  end
end
