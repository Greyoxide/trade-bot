# frozen_string_literal: true

module Alpaca
  class Market
    def initialize(client: Client.new)
      @client = client
    end

    # Returns all active, tradeable US equity symbols
    def symbols(asset_class: "us_equity")
      assets = @client.trading_get("/v2/assets", status: "active", asset_class: asset_class)
      assets.select { |a| a["tradable"] }.map { |a| a["symbol"] }
    end

    # Returns OHLCV bars for a symbol.
    # period: :day, :week, :month, :ytd, :year, or pass start/end explicitly.
    def history(symbol, period: :month, timeframe: "1Day", start_date: nil, end_date: nil)
      start_date ||= period_start(period)
      end_date   ||= Date.today.to_s

      params = {
        symbols:   symbol.to_s.upcase,
        timeframe: timeframe,
        start:     start_date,
        end:       end_date,
        limit:     1000,
        feed:      "iex"
      }

      result = @client.data_get("/v2/stocks/bars", params)
      bars   = result.dig("bars", symbol.to_s.upcase) || []

      bars.map do |bar|
        {
          time:   bar["t"],
          open:   bar["o"].to_f,
          high:   bar["h"].to_f,
          low:    bar["l"].to_f,
          close:  bar["c"].to_f,
          volume: bar["v"].to_i
        }
      end
    end

    # Latest quote for a symbol
    def quote(symbol)
      result = @client.data_get("/v2/stocks/#{symbol.upcase}/quotes/latest", feed: "iex")
      result["quote"]
    end

    # Latest trade price
    def latest_price(symbol)
      result = @client.data_get("/v2/stocks/#{symbol.upcase}/trades/latest", feed: "iex")
      result.dig("trade", "p")&.to_f
    end

    private

    def period_start(period)
      case period
      when :day   then (Date.today - 1).to_s
      when :week  then (Date.today - 7).to_s
      when :month then (Date.today - 30).to_s
      when :ytd   then Date.new(Date.today.year, 1, 1).to_s
      when :year  then (Date.today - 365).to_s
      else              (Date.today - 30).to_s
      end
    end
  end
end
