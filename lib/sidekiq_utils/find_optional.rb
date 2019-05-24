module SidekiqUtils
  module FindOptional
    extend ActiveSupport::Concern

    class NotFoundError < StandardError; end
    class NotUpdatedError < StandardError; end

    # try finding a record, but eventually give up retrying if we still cannot
    # find it. use this if you are trying to load a record from a job, but
    # don't want the failed job to end up in the RetrySet if it keeps failing.
    def find_optional(entity, id, scope: nil, updated_at: nil)
      entity = entity.public_send(scope) if scope
      if id.is_a?(Enumerable)
        instance = entity.where(id: id)
      else
        instance = entity.find_by(id: id)
      end

      raise(NotFoundError) unless instance.present?
      raise(NotUpdatedError) if updated_at < instance.updated_at

      instance
    end
  end
end
