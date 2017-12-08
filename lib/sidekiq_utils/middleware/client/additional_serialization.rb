module SidekiqUtils
  module Middleware
    module Client
      class AdditionalSerialization
        def call(worker_class, job, queue, redis_pool)
          if job['class'] == "ActiveJob::QueueAdapters::SidekiqAdapter::JobWrapper"
            # this is handled in ActiveJob, as it would otherwise raise an
            # exception before it even gets here
            return yield
          end

          job['args'] = job['args'].map do |arg|
            ::SidekiqUtils::AdditionalSerialization.wrap_argument(arg)
          end
          yield
        end
      end
    end
  end
end
