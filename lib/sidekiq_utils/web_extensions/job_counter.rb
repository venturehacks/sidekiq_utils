module SidekiqUtils
  module WebExtensions
    module JobCounter
      def self.registered(app)
        view_path = File.join(File.expand_path("..", __FILE__), "views")

        require 'active_support/number_helper'
        app.get("/job_counts") do
          @throughput = SidekiqUtils::RedisMonitorStorage.
              retrieve('sidekiq_elapsed', 'elapsed')
          @counts = []
          SidekiqUtils::JobCounter.counts.each do |queue, job_counts|
            job_counts.each do |job, count|
              values = { queue: queue, job: job, count: count }
              if (values[:avg_runtime] = @throughput[job].try!(:[], 'average'))
                execution_time = values[:count] * values[:avg_runtime].to_f / 1_000
                values[:runtime_day] = days =
                  (execution_time / 1.day).floor
                values[:runtime_hour] = hours =
                  ((execution_time - days.days) / 1.hour).floor
                values[:runtime_min] = (
                  (execution_time - days.days - hours.hours) / 1.minute
                ).round
              end
              @counts << values
            end
          end
          @counts.sort_by! {|x| -1 * x[:count] }

          render(:erb, File.read(File.join(view_path, "job_counts.erb")))
        end
      end
    end
  end
end
