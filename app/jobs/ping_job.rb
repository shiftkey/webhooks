class PingJob < ApplicationJob
    queue_as :default

    def perform(payload)
      obj = JSON.parse(payload)
      logger.info "Got ping event with message '#{obj[:zen]}'"
    end
  end
