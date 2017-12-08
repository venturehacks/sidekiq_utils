module SidekiqUtils
  module Deprioritize
    def self.workers(*workers)
      workers = workers.map do |worker|
        if worker.is_a?(Class)
          worker.name
        else
          worker
        end
      end

      old_deprioritized = Thread.current[:deprioritize_worker_classes]
      Thread.current[:deprioritize_worker_classes] ||= []
      Thread.current[:deprioritize_worker_classes] |= workers
      yield
      Thread.current[:deprioritize_worker_classes] = old_deprioritized
    end
  end
end
