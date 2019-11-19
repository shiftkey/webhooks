class WelcomeController < ApplicationController
  def index
    logger.info "The current time is '#{Time.now}'"

    PullRequestReviewJob.perform_later("doing something")

    render "index"
  end
end
