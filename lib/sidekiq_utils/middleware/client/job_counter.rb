module SidekiqUtils
  module Middleware
    module Client
      class JobCounter
        def call(worker_class, job, queue, redis_pool)
          unless job['at']
            # don't count when jobs get put on the scheduled set, because
            # otherwise we'll double-count them when they get popped and moved
            # to a work queue.
            SidekiqUtils::JobCounter.increment(job)
          end
          yield
        end
      end
    end
  end
end
