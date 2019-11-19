class PullRequestJob < ApplicationJob
  queue_as :default

  def perform(payload)
    obj = JSON.parse(payload)
    logger.info "Got pull_request event with action '#{obj[:action]}'"
  end
end
