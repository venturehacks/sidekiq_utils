module SidekiqUtils
  module RedisMonitorStorage
    class << self
      def add_first_argument_to_job_key(*klasses)
        @first_argument_to_job_key_for ||= []
        @first_argument_to_job_key_for |= klasses
      end

      def store(key, prefix, job, value)
        Sidekiq.redis do |redis|
          redis.multi do
            redis.hincrby(key, full_prefix(job, prefix, 'sum'), value)
            redis.hincrby(key, full_prefix(job, prefix, 'count'), 1)
          end
        end
      end

      def retrieve(top_level_key, prefix)
        data = {}
        Sidekiq.redis {|r| r.hgetall(top_level_key) }.each do |key, value|
          (job, prefix_type, date, value_type) = key.split('||')
          next unless prefix_type == prefix

          if Date.parse(date) < 1.week.ago
            # expired data, get rid of it
            Sidekiq.redis {|r| r.hdel(top_level_key, key) }
          else
            data[job] ||= { 'sum' => 0, 'count' => 0 }
            data[job][value_type] += value.to_i
          end
        end

        data.each do |job, values|
          values['average'] = (values['sum'].to_f / values['count'].to_i).round
        end
        data
      end

      def full_prefix(job, prefix = nil, last_prefix = nil)
        job_prefix = job_prefix(job)
        full_prefix = [job_prefix, prefix, Date.today.to_s(:medium), last_prefix]
        full_prefix.compact.join('||')
      end

      def job_prefix(job, unwrap_arguments: false)
        arguments = arguments(job)
        if unwrap_arguments
          arguments = arguments.
            map {|arg| SidekiqUtils::AdditionalSerialization.unwrap_argument(arg) }
        end

        if active_job?(job)
          job_prefix = job['wrapped']
        else
          job_prefix = job['class']
        end

        case job_prefix
        when 'ActionMailer::DeliveryJob'
          job_prefix += "[#{arguments[0..1].join('#')}]"
        when *(@first_argument_to_job_key_for.to_a)
          job_prefix += "[#{arguments[0]}]"
        end

        job_prefix
      end

      def arguments(job)
        if active_job?(job)
          job['args'].first['arguments']
        else
          job['args']
        end
      end

      def active_job?(job)
        job['class'] == "ActiveJob::QueueAdapters::SidekiqAdapter::JobWrapper"
      end
    end
  end
end
