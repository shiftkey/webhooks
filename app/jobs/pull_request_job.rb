class PullRequestJob < ApplicationJob
  queue_as :default

  def perform(payload)
    obj = JSON.parse(payload)

    action = obj['action']
    pull_request_number = obj['number']
    subject_id = obj['pull_request']['node_id']
    base_sha = obj['pull_request']['base']['sha']
    base_ref = obj['pull_request']['base']['ref']
    head_sha = obj['pull_request']['head']['sha']
    full_name = obj['pull_request']['head']['full_name']
    default_branch = obj['pull_request']['base']['repo']['default_branch']

    logger.info "Action '#{obj['action']}' for PR ##{pull_request_number} on repo '#{full_name}'"

    unless action == 'synchronize' || action == 'opened' || action == 'reopened'
      logger.info "Pull request action #{action} is not handled. Ignoring..."
      return
    end

    unless base_ref == 'gh-pages'
      logger.info "Pull request targets '#{base_ref}'' rather than the default branch. Ignoring..."
      return
    end

    logger.info "TODO: clone a repository to the temporary directory"
    logger.info "TODO: find changes to files in diff #{base_sha}...#{head_sha}"
  end
end
