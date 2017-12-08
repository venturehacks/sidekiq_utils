require 'objspace'

module SidekiqUtils
  module Middleware
    module Server
      class MemoryMonitor
        def call(worker, job, queue)
          return yield unless Sidekiq.options[:concurrency] == 1

          objects_before = count_allocated_objects
          memory_before = get_allocated_memory

          GC.start(full_mark: true)
          GC.disable
          begin
            yield
          ensure
            GC.enable
            GC.start(full_mark: true)
            objects_after = count_allocated_objects
            memory_after = get_allocated_memory

            object_growth = objects_after - objects_before
            SidekiqUtils::RedisMonitorStorage.store(
              'sidekiq_memory', 'object', job, object_growth)
            Sidekiq.logger.info("Object growth: #{object_growth}")

            memory_growth = memory_after - memory_before
            SidekiqUtils::RedisMonitorStorage.store(
              'sidekiq_memory', 'memory', job, memory_growth)
            Sidekiq.logger.info("Memory growth: #{memory_growth}")
          end
        end

        private
        def count_allocated_objects
          ObjectSpace.each_object.inject(0) {|count, obj| count + 1 }
        end

        def get_allocated_memory
          ObjectSpace.memsize_of_all
        end
      end
    end
  end
end
