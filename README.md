# sidekiq_utils
Sidekiq powers our background processing needs at AngelList. As we introduced Sidekiq in a legacy codebase and it started to handle significant job throughput, we developed a number of utilities to make working with Sidekiq easier that we'd love to share.

## Additional Serialization

Adds support for automatically serializing and deserializing additional argument types for your workers:
* `Class`
* `Symbol` (both by themselves and as hash keys)
* `ActiveSupport::HashWithIndifferentAccess`

To use this utility, you need to include the client and server middlewares. Be sure to include the client middleware on the server as well.

### Configuration
```
Sidekiq.configure_server do |config|
  config.server_middleware do |chain|
    chain.add ::SidekiqUtils::Middleware::Server::AdditionalSerialization
  end
  config.client_middleware do |chain|
    chain.add ::SidekiqUtils::Middleware::Client::AdditionalSerialization
  end
end
Sidekiq.configure_client do |config|
  config.client_middleware do |chain|
    chain.add ::SidekiqUtils::Middleware::Client::AdditionalSerialization
  end
end
```

### A note of caution for users of the sidekiq-unique-jobs gem

sidekiq-unique-jobs will fail to properly determine job uniqueness if you don't hook the middlewares in the correct order. If you use both sidekiq-unique-jobs and the additional serialization utility, be sure to hook your middlewares in the following way:
```
Sidekiq.configure_server do |config|
  # unwrap arguments first
  config.server_middleware do |chain|
    chain.add ::SidekiqUtils::Middleware::Server::AdditionalSerialization
  end
  # then determine unique jobs
  SidekiqUniqueJobs.configure_server_middleware

  # first determine uniqueness
  SidekiqUniqueJobs.configure_client_middleware
  # then wrap arguments
  config.client_middleware do |chain|
    chain.add ::SidekiqUtils::Middleware::Client::AdditionalSerialization
  end
end
Sidekiq.configure_client do |config|
  # first determine uniqueness
  SidekiqUniqueJobs.configure_client_middleware
  # then wrap arguments
  config.client_middleware do |chain|
    chain.add ::SidekiqUtils::Middleware::Client::AdditionalSerialization
  end
end
```

## Deprioritize

Adds an easy ability to divert jobs added within a block to a lower-priority queue. This is useful, for example, in cron jobs. All jobs added within the block will be added to the `low` queue instead of their default queue.

### Configuration

```
Sidekiq.configure_server do |config|
  config.client_middleware do |chain|
    chain.add SidekiqUtils::Middleware::Client::Deprioritize
  end
end
Sidekiq.configure_client do |config|
  config.client_middleware do |chain|
    client_middlewares.each do |middleware|
      chain.add SidekiqUtils::Middleware::Client::Deprioritize
    end
  end
end
```

### Usage

```
SidekiqUtils::Deprioritize.workers(SolrIndexWorker) do
  10_000.times do
    # these will all go to the `low` queue
    SolrIndexWorker.perform_async(User, rand(10_000))
  end
end
```

## Enqueued jobs helper

A simple tool to inspect and manipulate Sidekiq queues from the console:

```
> SidekiqUtils::EnqueuedJobsHelper.counts
=> {"default"=>{}, "high"=>{"AlgoliaIndexWorker[JobProfile]"=>1}, "low"=>{"AlgoliaIndexWorker[JobProfile]"=>1}}

> SidekiqUtils::EnqueuedJobsHelper.delete(queue: 'low', job_class: 'AlgoliaIndexWorker', first_argument: JobProfile)
# first_argument is optional
```

## Find optional

Lots of jobs become moot when a record cannot be found; however, because Sidekiq is very fast and it's easy to forget to enqueue jobs in `after_commit` hooks, sometimes the record isn't found simply because the transaction in which it was inserted has not been committed yet. This will retry a `find_optional` call exactly once after 30 seconds if the record cannot be found.

### Configuration

```
Sidekiq.configure_server do |config|
  config.server_middleware do |chain|
    chain.add SidekiqUtils::Middleware::Server::FindOptional
  end
end
```

### Usage

```
class SolrIndexWorker
  include Sidekiq::Worker

  def perform(user_id)
    user = find_optional(User, user_id)
  end
end
```

## Latency monitor

This will monitor queue latency and report to Slack channels if the latency exceeds the configured threshold.

### Configuration

Create a `config/sidekiq_utils.yml` file in your project:
```
repeat_alert_every: 60 # repeat identical alerts every x minutes
alert_thresholds: # in minutes
  default: 10
  high: 5
  low: 60
slack:
  username: 'Sidekiq alerts'
  icon: 'alarm_clock'
  team: 'foobar'
  token: 'xxx'
  channels_to_alert:
    - "#devops-alerts"
    - "#sidekiq-alerts"
```

### Usage

Simply call `SidekiqUtils::LatencyAlert.check!` at regular intervals.

## Throughput monitor

This will keep track of how many jobs of which worker class have run in the past week, as well as when it was last run.

### Configuration

```
Sidekiq.configure_server do |config|
  config.server_middleware do |chain|
    chain.add SidekiqUtils::Middleware::Server::ThroughputMonitor
  end
end
Sidekiq::Web.register SidekiqUtils::WebExtensions::ThroughputMonitor
Sidekiq::Web.tabs["Throughput"] = "throughput"
```

### Usage

This will add a "Throughput" tab to your Sidekiq admin which will display job throughput information.
