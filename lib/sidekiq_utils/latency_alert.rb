require 'yaml'

module SidekiqUtils
  class LatencyAlert
    REDIS_KEY = "sidekiq_queue_latency_alert"

    class << self
      def check!
        alerts = {}
        Sidekiq::Queue.all.each do |queue|
          threshold = config['alert_thresholds'][queue.name].
            try!(&:to_i).try!(:minutes)
          next if threshold == :disabled
          threshold ||= config['alert_thresholds']['default'].
            try!(&:to_i).try!(:minutes) || 10.minutes
          if (latency = queue.latency) > threshold
            alerts[queue.name] = latency
          end
        end

        if alerts.blank?
          if should_alert_back_to_normal?
            Sidekiq.redis { |r| r.del(REDIS_KEY) }
            slack_alert("All queues under their thresholds.")
          end
          return false
        end

        alert_message = ["Sidekiq queue latency over threshold:"]
        alerts.each do |queue, latency|
          alert_message << "Queue #{queue} is #{formatted_latency(latency)} behind"
        end
        alert_message = alert_message.join("\n")
        if should_alert_again?(alert_message)
          slack_alert(alert_message)
        end

        true
      end

      def config
        @config ||= (YAML.load(ERB.new(
          File.read('config/sidekiq_utils.yml')).result) || {})
      end

      private
      def formatted_latency(latency)
        latency_days = (latency.to_f / 1.day).floor
        if latency < 1.day
          formatted_latency =
            ActionController::Base.helpers.distance_of_time_in_words(latency)
        else
          formatted_latency = "#{latency_days} #{"day".pluralize(latency_days)}"
        end
        if latency > 1.day
          latency_in_day = latency - latency_days * 1.day
          if latency_in_day >= 45.minutes
            formatted_latency += " and " +
              ActionController::Base.helpers.
                distance_of_time_in_words(latency_in_day)
          end
        end
        formatted_latency
      end

      def slack_alert(alert_message)
        Array.wrap(config['channels_to_alert']).each do |slack_name|
          Slack.send_message(
            slack_name, alert_message,
            icon: ':alarm_clock:', username: 'Sidekiq alerts')
        end
      end

      def should_alert_back_to_normal?
        Sidekiq.redis do |redis|
          redis.get(REDIS_KEY).present?
        end
      end

      def should_alert_again?(message)
        Sidekiq.redis do |redis|
          last_alert = redis.get(REDIS_KEY)
          last_alert = JSON.parse(last_alert) if last_alert
          if !last_alert ||
              last_alert['message_hash'] != Digest::SHA1.hexdigest(message) ||
              last_alert['time'] < (config['repeat_alert_every'] || 60).to_i.minutes.ago.to_i
            redis.set(REDIS_KEY, {
              'message_hash' => Digest::SHA1.hexdigest(message),
              'time' => Time.now.to_i,
            }.to_json)
            true
          else
            false
          end
        end
      end
    end
  end
end
