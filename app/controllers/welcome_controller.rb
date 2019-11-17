class WelcomeController < ApplicationController
  def index
    logger.info "The current time is '#{Time.now}'"
    render "index"
  end
end
