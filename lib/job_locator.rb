# frozen_string_literal: true

class JobLocator
  def self.find_job_for_event(event, payload)
    case event
    when 'ping'
      PingJob
    when 'pull_request'
      check_pull_request(payload)
    end
  end

  def self.check_pull_request(payload)
    UpForGrabsPullRequestProjectAnalyzerJob if UpForGrabsPullRequestProjectAnalyzerJob.can_process(payload)
  end
end
