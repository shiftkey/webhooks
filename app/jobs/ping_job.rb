# frozen_string_literal: true

class PingJob < ApplicationJob
  queue_as :default

  def self.can_process(payload)
    true
  end

  def perform(payload)
    obj = JSON.parse(payload)
    logger.info "Got ping event with message '#{obj['zen']}'"
  end
end
