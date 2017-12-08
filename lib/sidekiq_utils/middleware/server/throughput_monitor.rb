module SidekiqUtils
  module Middleware
    module Server
      class ThroughputMonitor
        def call(worker, job, queue)
          start = Time.now
          begin
            yield
          ensure
            elapsed = Time.now - start
            elapsed_ms = (elapsed * 1_000).round

            SidekiqUtils::RedisMonitorStorage.store(
              'sidekiq_elapsed', 'elapsed', job, elapsed_ms)
            Sidekiq.redis do |redis|
              redis.hset('sidekiq_last_run',
                         SidekiqUtils::RedisMonitorStorage.job_prefix(job),
                         Time.now.to_i)
            end
          end
        end
      end
    end
  end
end
