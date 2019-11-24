# frozen_string_literal: true

class JobLocator
  def self.find_job_for_event(event, payload)
    if event == 'ping'
      PingJob.class
    elsif event == 'pull_request'
      check_pull_request(payload)
    end
  end

  def self.check_pull_request(payload)
    PullRequestJob.class if PullRequestJob.can_process(payload)
  end
end
