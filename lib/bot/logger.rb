# frozen_string_literal: true

require "logger"
require "fileutils"

module Bot
  module Log
    LOG_DIR  = File.expand_path("../../log", __dir__)
    LOG_FILE = File.join(LOG_DIR, "trade_bot.log").freeze

    def self.setup
      FileUtils.mkdir_p(LOG_DIR)

      file_logger   = ::Logger.new(LOG_FILE, "daily")
      stdout_logger = ::Logger.new($stdout)

      [file_logger, stdout_logger].each do |l|
        l.formatter = proc do |severity, datetime, _progname, msg|
          "[#{datetime.strftime('%Y-%m-%d %H:%M:%S')}] #{severity}: #{msg}\n"
        end
      end

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
      msg = "[TRADE] #{action.upcase} #{symbol.upcase} — #{detail}"
      info(msg)
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
