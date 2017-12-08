module SidekiqUtils
  module WebExtensions
    module MemoryMonitor
      def self.registered(app)
        view_path = File.join(File.expand_path("..", __FILE__), "views")

        require 'active_support/number_helper'
        app.get("/memory") do
          memory = SidekiqUtils::RedisMonitorStorage.retrieve('sidekiq_memory', 'memory')
          object = SidekiqUtils::RedisMonitorStorage.retrieve('sidekiq_memory', 'object')

          @memory = (memory.keys | object.keys).map do |job|
            [job,
             memory[job]['average'],
             object[job]['average'],
             memory[job]['sum'],
             object[job]['sum'],
            ]
          end.sort_by {|x| -x[3] }

          render(:erb, File.read(File.join(view_path, "memory.erb")))
        end
      end
    end
  end
end
