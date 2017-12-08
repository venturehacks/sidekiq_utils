module SidekiqUtils
  module Middleware
    module Server
      class JobCounter
        def call(worker, job, queue)
          # we decrement here whether the job succeeds or not, because
          # re-enqueuing from the retry queue triggers the client middleware
          # and thus another increment even in the case of an error
          SidekiqUtils::JobCounter.decrement(job)
          yield
        end
      end
    end
  end
end
