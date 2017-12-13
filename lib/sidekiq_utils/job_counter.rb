require 'sidekiq_utils/redis_monitor_storage'

module SidekiqUtils
  module JobCounter
    REDIS_KEY = 'sidekiq_utils_job_counter'
    LOCK = Mutex.new
    SYNC_COUNTS_EVERY = 1 # second

    class << self
      def increment(job)
        change_count(job, 1)
      end

      def decrement(job)
        change_count(job, -1)
      end

      def counts
        Sidekiq.redis do |redis|
          redis.hgetall(REDIS_KEY).each_with_object({}) do |(key, count), ret_hash|
            key_hash = JSON.parse(key, symbolize_names: true)

            count = count.to_i
            if count != 0
              ret_hash[key_hash[:queue]] ||= {}
              ret_hash[key_hash[:queue]][key_hash[:job]] = count
            end
          end
        end
      end

      def reset!
        Sidekiq.redis do |redis|
          redis.del(REDIS_KEY)
        end
      end

      def hook_sidekiq!
        Sidekiq::SortedEntry.prepend(SortedEntry::JobCounterExtension)
        Sidekiq::ScheduledSet.prepend(ScheduledSet::JobCounterExtension)
        Sidekiq::Job.prepend(Job::JobCounterExtension)
        Sidekiq::Queue.prepend(Queue::JobCounterExtension)
        Sidekiq::JobSet.prepend(JobSet::JobCounterExtension)
      end

      private
      def change_count(job, change_by)
        unless [-1, 1].include?(change_by)
          fail("Unsupported change_by value: #{change_by}")
        end

        job_key = SidekiqUtils::RedisMonitorStorage.job_prefix(
            job, unwrap_arguments: true)
        hash_key = {
          queue: job['queue'],
          job: job_key,
        }.to_json

        LOCK.synchronize do
          @counts_to_flush ||= {}
          @counts_to_flush[hash_key] ||= 0
          @counts_to_flush[hash_key] += change_by

          if ENV['RAILS_ENV'] == 'test'
            @sync_thread ||= Thread.new do
              sleep SYNC_COUNTS_EVERY
              sync_to_redis
            end
          end
        end

        sync_to_redis if ENV['RAILS_ENV'] == 'test'
      end

      def sync_to_redis
        local_counts_to_flush = nil
        LOCK.synchronize do
          local_counts_to_flush = @counts_to_flush
          @counts_to_flush = {}
          @sync_thread = nil
        end
        (local_counts_to_flush || {}).each do |hash_key, change_by|
          Sidekiq.redis do |redis|
            count = redis.hincrby(REDIS_KEY, hash_key, change_by)
            if count < 0 && change_by < 0
              # this shouldn't happen, but it could when we first deploy this.
              # just makes sure we don't end up with negative values here
              # which don't make sense
              #
              # we only ever increment by the same amount we just did because
              # we can't be responsible for more of a discrepancy at this
              # point and we don't want multiple threads to overcorrect for
              # each other
              count = redis.hincrby(REDIS_KEY, hash_key, -1*change_by)
            end
          end
        end
      end
      at_exit { SidekiqUtils::JobCounter.send(:sync_to_redis) }
    end
  end

  class SortedEntry
    module JobCounterExtension
      def delete
        if super
          JobCounter.decrement(item)
        end
      end

      private

      def remove_job
        super do |message|
          JobCounter.decrement(Sidekiq.load_json(message))
          yield message
        end
      end
    end
  end

  class ScheduledSet
    module JobCounterExtension
      def delete
        if super
          JobCounter.decrement(item)
        end
      end
    end
  end

  class Job
    module JobCounterExtension
      def delete
        super
        JobCounter.decrement(item)
      end
    end
  end

  class Queue
    module JobCounterExtension
      def clear
        super
      end
    end
  end

  class JobSet
    module JobCounterExtension
      def clear
        each(&:delete)
        super
      end

      def delete_by_value(name, value)
        if super
          JobCounter.decrement(Sidekiq.load_json(value))
        end
      end
    end
  end
end
