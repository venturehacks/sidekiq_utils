require 'spec_helper'
require 'sidekiq/testing'
require 'sidekiq_utils/job_counter'
require 'sidekiq_utils/middleware/server/job_counter'
require 'sidekiq_utils/middleware/client/job_counter'

describe SidekiqUtils::JobCounter do
  class ApplicationWorker
    include Sidekiq::Worker
  end
  class TestWorker1 < ApplicationWorker
    def perform; end
  end
  class TestWorker2 < ApplicationWorker
    def perform; end
  end

  before do
    Sidekiq.configure_client do |config|
      config.client_middleware do |chain|
        chain.add SidekiqUtils::Middleware::Client::JobCounter
      end
    end
    Sidekiq::Testing.server_middleware do |chain|
      chain.add SidekiqUtils::Middleware::Server::JobCounter
    end
  end

  after do
    Sidekiq::Testing.server_middleware.clear
    Sidekiq.configure_client do |config|
      config.client_middleware do |chain|
        chain.remove SidekiqUtils::Middleware::Client::JobCounter
      end
    end
  end

  it 'keeps correct counts' do
    # normally, we wouldn't need this because the spec_helper resets all the
    # queues for us before every test. but that doesn't invoke the normal
    # queue code that we hook into, so we have to _specificially_ reset also
    SidekiqUtils::JobCounter.reset!
    assert_counts({})

    TestWorker1.set(queue: 'default').perform_async
    assert_counts({'default' => {'TestWorker1' => 1}})

    TestWorker1.set(queue: 'default').perform_async
    assert_counts({'default' => {'TestWorker1' => 2}})

    TestWorker1.set(queue: 'low').perform_async
    assert_counts({'default' => {'TestWorker1' => 2},
                   'low' => {'TestWorker1' => 1}})

    TestWorker2.set(queue: 'default').perform_async
    assert_counts({'default' => {'TestWorker1' => 2,
                                 'TestWorker2' => 1},
                   'low' => {'TestWorker1' => 1}})

    TestWorker2.set(queue: 'low').perform_async
    assert_counts({'default' => {'TestWorker1' => 2,
                                 'TestWorker2' => 1},
                   'low' => {'TestWorker1' => 1,
                             'TestWorker2' => 1}})

    TestWorker1.drain
    assert_counts({'default' => {'TestWorker2' => 1},
                   'low' => {'TestWorker2' => 1}})

    TestWorker2.drain
    assert_counts({})
  end

  it 'resets a negative count correctly' do
    SidekiqUtils::JobCounter.reset!
    assert_counts({})

    job = {
      'class' => 'TestWorker',
      'args' => [],
      'queue' => 'default',
    }

    SidekiqUtils::JobCounter.decrement(job)
    assert_counts({})

    SidekiqUtils::JobCounter.increment(job)
    assert_counts({'default' => {'TestWorker' => 1}})
  end

  def assert_counts(hash)
    expect(SidekiqUtils::JobCounter.counts).to eq(hash)
  end
end
