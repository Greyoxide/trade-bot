# frozen_string_literal: true

require_relative "lib/bot"

configs = Dir[File.expand_path("config/bots/*.yml", __dir__)]
abort "No bot configs found in config/bots/" if configs.empty?

threads = configs.map do |path|
  Thread.new { Bot::Runner.new(path).run_loop }
end

threads.each(&:join)
