# frozen_string_literal: true

require "logger"
require "fileutils"

module Bot
  module Log
    COLORS = {
      "red"     => "\e[31m",
      "green"   => "\e[32m",
      "yellow"  => "\e[33m",
      "blue"    => "\e[34m",
      "magenta" => "\e[35m",
      "cyan"    => "\e[36m",
      "white"   => "\e[37m"
    }.freeze
    RESET = "\e[0m".freeze

    LOG_DIR = File.expand_path("../../log", __dir__)

    def self.setup(symbol: nil, color: nil)
      FileUtils.mkdir_p(LOG_DIR)

      log_file = symbol ? File.join(LOG_DIR, "#{symbol.downcase}.log") : File.join(LOG_DIR, "trade_bot.log")

      file_logger   = ::Logger.new(log_file, "daily")
      stdout_logger = ::Logger.new($stdout)

      plain_fmt = proc { |severity, datetime, _progname, msg|
        "[#{datetime.strftime('%Y-%m-%d %H:%M:%S')}] #{severity}: #{msg}\n"
      }

      color_code = COLORS[color.to_s.downcase]
      color_fmt  = proc { |severity, datetime, _progname, msg|
        line = "[#{datetime.strftime('%Y-%m-%d %H:%M:%S')}] #{severity}: #{msg}\n"
        color_code ? "#{color_code}#{line}#{RESET}" : line
      }

      file_logger.formatter   = plain_fmt
      stdout_logger.formatter = color_fmt

      @logger = MultiLogger.new(file_logger, stdout_logger)
    end

    def self.logger
      @logger || setup
    end

    def self.info(msg)  = logger.info(msg)
    def self.warn(msg)  = logger.warn(msg)
    def self.error(msg) = logger.error(msg)
    def self.debug(msg) = logger.debug(msg)

    def self.trade(action, symbol, detail)
      info("[TRADE] #{action.upcase} #{symbol.upcase} — #{detail}")
    end

    class MultiLogger
      def initialize(*loggers)
        @loggers = loggers
      end

      %i[info warn error debug].each do |level|
        define_method(level) { |msg| @loggers.each { |l| l.public_send(level, msg) } }
      end
    end
  end
end
