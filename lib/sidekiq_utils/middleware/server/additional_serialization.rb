module SidekiqUtils
  module Middleware
    module Server
      class AdditionalSerialization
        def call(worker, job, queue)
          if job['class'] == "ActiveJob::QueueAdapters::SidekiqAdapter::JobWrapper"
            # this is handled in ActiveJob, as it would otherwise raise an
            # exception before it even gets here
            return yield
          end

          job['args'] = job['args'].map do |arg|
            ::SidekiqUtils::AdditionalSerialization.unwrap_argument(arg)
          end
          yield
        end
      end
    end
  end
end
