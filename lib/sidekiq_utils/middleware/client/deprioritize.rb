module SidekiqUtils
  module Middleware
    module Client
      class Deprioritize
        def call(worker_class, job, queue, redis_pool)
          if Thread.current[:deprioritize_worker_classes].to_a.include?(worker_class)
            job['queue'] = 'low'
          end
          yield
        end
      end
    end
  end
end
