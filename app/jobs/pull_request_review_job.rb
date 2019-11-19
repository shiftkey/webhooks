class PullRequestReviewJob < ApplicationJob
  queue_as :default

  def perform(name, payload=nil)
    logger.info "Running job with name: '#{name}' at '#{Time.now}'"
  end
end
