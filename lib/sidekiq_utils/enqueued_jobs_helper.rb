module SidekiqUtils
  module EnqueuedJobsHelper
    class << self
      def counts
        counts = {}
        Sidekiq::Queue.all.each do |queue|
          queue_job_counts = counts[queue.name] ||= {}
          queue.each do |job|
            job_key = SidekiqUtils::RedisMonitorStorage.job_prefix(
                job, unwrap_arguments: true)
            queue_job_counts[job_key] ||= 0
            queue_job_counts[job_key] += 1
          end
        end
        counts
      end

      def delete(queue:, job_class:, first_argument: nil)
        if job_class.is_a?(Class)
          job_class = job_class.name
        else
          job_class = job_class.to_s
        end

        deleted = 0
        Sidekiq::Queue.all.each do |iter_queue|
          next if queue && queue.to_s != iter_queue.name

          iter_queue.each do |job|
            next if job['class'] != job_class
            if first_argument && SidekiqUtils::AdditionalSerialization.
                unwrap_argument(job['args'].first) != first_argument
              next
            end

            job.delete
            deleted += 1
          end
        end

        deleted
      end
    end
  end
end
