class PullRequestJob < ApplicationJob
  queue_as :default

  def perform(payload)
    obj = JSON.parse(payload)

    action = obj['action']
    pull_request_number = obj['number']

    pull_request = obj['pull_request']
    base = pull_request['base']
    head = pull_request['head']
    subject_id = pull_request['node_id']

    base_sha = base['sha']
    base_ref = base['ref']
    head_sha = head['sha']

    repo = base['repo']
    default_branch = repo['default_branch']

    logger.info "Action '#{obj['action']}' for PR ##{pull_request_number} on repo '#{repo['full_name']}'"

    unless action == 'synchronize' || action == 'opened' || action == 'reopened'
      logger.info "Pull request action #{action} is not handled. Ignoring..."
      return
    end

    unless base_ref == default_branch
      logger.info "Pull request targets '#{base_ref}' rather than the default branch '#{default_branch}'. Ignoring..."
      return
    end

    logger.info "TODO: clone a repository to the temporary directory"
    logger.info "TODO: find changes to files in diff #{base_sha}...#{head_sha}"
  end
end
