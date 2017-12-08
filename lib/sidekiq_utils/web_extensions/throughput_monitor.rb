module SidekiqUtils
  module WebExtensions
    module ThroughputMonitor
      def self.registered(app)
        view_path = File.join(File.expand_path("..", __FILE__), "views")

        app.get("/throughput") do
          last_run_at = {}
          Sidekiq.redis {|r| r.hgetall('sidekiq_last_run') }.each do |job, last_run|
            last_run_at[job] = last_run
          end
          @throughput = SidekiqUtils::RedisMonitorStorage.
              retrieve('sidekiq_elapsed', 'elapsed').map do |job, values|

            if last_run_at[job]
              last_run_time = Time.at(Integer(last_run_at[job])).
                in_time_zone('US/Eastern').to_s(:long) + ' ET'
            else
              last_run_time = 'n/a'
            end
            [job,
             values['average'],
             values['count'],
             last_run_time,
            ]
          end.sort_by {|x| -x[2] }
          render(:erb, File.read(File.join(view_path, "throughput.erb")))
        end
      end
    end
  end
end
