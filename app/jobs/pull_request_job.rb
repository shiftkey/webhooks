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

    base_repo = base['repo']
    head_repo = base['repo']
    default_branch = base_repo['default_branch']

    logger.info "Action '#{obj['action']}' for PR ##{pull_request_number} on repo '#{base_repo['full_name']}'"

    unless action == 'synchronize' || action == 'opened' || action == 'reopened'
      logger.info "Pull request action #{action} is not handled. Ignoring..."
      return
    end

    unless base_ref == default_branch
      logger.info "Pull request targets '#{base_ref}' rather than the default branch '#{default_branch}'. Ignoring..."
      return
    end

    clone_url = head_repo['clone_url']
    range = "#{base_sha}...#{head_sha}"

    Dir.mktmpdir do |dir|
      system("git", "clone", "--", clone_url, dir)
      # TODO: handle failure when head_sha no longer exists
      system("git", "-C", dir, "checkout", head_sha)
      system("git", "-C", dir, "diff", range, "--name-only", "--" ,"_data/projects/")
    end

  end
end
