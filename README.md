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
  # code that enqueues lots of SolrIndexWorker that will now
  # all end up on the `low` queue
end
```
