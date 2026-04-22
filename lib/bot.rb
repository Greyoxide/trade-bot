# frozen_string_literal: true

require "yaml"
require "openai"
require_relative "alpaca"
require_relative "bot/logger"

module Bot
  class Runner
    def initialize(config_path)
      config        = YAML.load_file(config_path, symbolize_names: true).fetch(:bot)
      @symbol       = config.fetch(:symbol).upcase
      @instructions = config.fetch(:instructions)
      @cycle        = parse_cycle(config[:cycle])

      Bot::Log.setup(symbol: @symbol, color: config[:color])

      @market   = Alpaca::Market.new
      @account  = Alpaca::Account.new
      @orders   = Alpaca::Orders.new

      @llm      = OpenAI::Client.new(access_token: ENV.fetch("OPENAI_API_KEY"))
      @messages = []
    end

    def run
      Bot::Log.info("Running cycle for #{@symbol}")
      context = gather_context
      execute(ask_llm(context))
    end

    def run_loop
      Bot::Log.info("Bot started for #{@symbol} — cycle: #{cycle_description}")

      loop do
        begin
          run
        rescue => e
          Bot::Log.error("#{e.class}: #{e.message}")
        end
        Bot::Log.info("Next run in #{cycle_description}")
        sleep @cycle
      end
    end

    private

    def gather_context
      position = @account.position(@symbol)
      history  = @market.history(@symbol, period: :month)
      price    = @market.latest_price(@symbol)
      account  = @account.info

      context = {
        symbol:        @symbol,
        latest_price:  price,
        buying_power:  account["buying_power"].to_f,
        equity:        account["equity"].to_f,
        position:      nil,
        price_history: history.last(30)
      }

      if position
        entry  = position["avg_entry_price"].to_f
        plpc   = price && entry > 0 ? ((price - entry) / entry * 100).round(2) : nil
        context[:position] = {
          qty:               position["qty"],
          avg_entry_price:   entry,
          current_price:     price,
          unrealized_pl_pct: plpc,
          market_value:      position["market_value"].to_f
        }
      end

      context
    end

    def ask_llm(context)
      pos         = context[:position]
      pos_summary = pos ? "#{pos[:qty]} shares @ #{pos[:avg_entry_price]} (#{pos[:unrealized_pl_pct]}% P&L)" : "none"
      Bot::Log.info("Context: price=#{context[:latest_price]} buying_power=#{context[:buying_power]} position=#{pos_summary}")

      @messages << { role: "user", content: context.to_json }

      response = @llm.chat(
        parameters: {
          model:    "gpt-4o",
          messages: [
            { role: "system", content: system_prompt },
            *@messages
          ],
          response_format: { type: "json_object" }
        }
      )

      content = response.dig("choices", 0, "message", "content")
      @messages << { role: "assistant", content: content }

      decision = JSON.parse(content)
      Bot::Log.info("LLM: action=#{decision['action']} rationale=#{decision['rationale']}")
      decision
    end

    def system_prompt
      <<~PROMPT
        #{@instructions.strip}

        ---

        Each cycle you will receive a JSON object with:
          - symbol: the ticker you are managing
          - latest_price: current market price
          - buying_power: available cash in the account
          - equity: total account value
          - position: current open position (null if none), with fields:
              qty, avg_entry_price, current_price, unrealized_pl_pct (%), market_value
          - price_history: array of recent daily OHLCV bars (time, open, high, low, close, volume)

        Respond with a JSON object containing:
          - action: (required) "buy", "sell", or "hold"
          - rationale: (required) one sentence explaining your reasoning

        If action is "buy", include one of:
          - amount_usd: dollar amount to spend
          - shares: number of shares to buy

        If action is "sell", include one of:
          - close_position: true — close the entire position
          - shares: number of shares to sell
      PROMPT
    end

    def parse_cycle(value)
      return 86_400 if value.nil?

      value = value.to_s.strip.downcase
      case value
      when /\A(\d+)h\z/ then $1.to_i * 3600
      when /\A(\d+)m\z/ then $1.to_i * 60
      when /\A(\d+)s\z/ then $1.to_i
      when /\A(\d+)d\z/ then $1.to_i * 86_400
      when "daily"      then 86_400
      when "hourly"     then 3_600
      else
        raise ArgumentError, "Unknown cycle format: #{value.inspect}. Use 4h, 30m, 1d, daily, hourly."
      end
    end

    def cycle_description
      h, rem = @cycle.divmod(3600)
      m       = rem / 60
      parts   = []
      parts << "#{h}h" if h > 0
      parts << "#{m}m" if m > 0
      parts.empty? ? "#{@cycle}s" : parts.join(" ")
    end

    def execute(decision)
      action = decision["action"]&.downcase
      symbol = @symbol

      case action
      when "buy"
        if (usd = decision["amount_usd"])
          Bot::Log.trade("buy", symbol, "$#{usd}")
          @orders.buy_dollars(symbol, usd)
        elsif (shares = decision["shares"])
          Bot::Log.trade("buy", symbol, "#{shares} shares")
          @orders.buy_shares(symbol, shares)
        else
          Bot::Log.warn("LLM returned buy without amount_usd or shares")
        end
      when "sell"
        if decision["close_position"]
          Bot::Log.trade("sell (close)", symbol, "entire position")
          @orders.close_position(symbol)
        elsif (shares = decision["shares"])
          Bot::Log.trade("sell", symbol, "#{shares} shares")
          @orders.sell_shares(symbol, shares)
        else
          Bot::Log.trade("sell (close)", symbol, "entire position (default)")
          @orders.close_position(symbol)
        end
      when "hold"
        Bot::Log.info("Holding #{symbol} — #{decision['rationale']}")
      else
        Bot::Log.warn("Unknown action from LLM: #{action}")
      end
    end
  end
end
