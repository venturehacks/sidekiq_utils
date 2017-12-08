module SidekiqUtils
  module Middleware
    module Server
      class FindOptional
        def call(worker, job, queue)
          begin
            yield
          rescue SidekiqUtils::FindOptional::NotFoundError
            if queue == 'retry_once'
              # do nothing; this is already the retry and it failed again
            else
              worker.class.set(queue: :retry_once).
                perform_in(30.seconds, *job['args'])
            end
          end
        end
      end
    end
  end
end
