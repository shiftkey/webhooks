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
      result = run "git clone -- '#{clone_url}' '#{dir}'"

      unless result[:exit_code] == 0
        logger.info "Unable to clone repository at #{clone_url} - check that you can access it..."
        logger.info "stderr: #{result[:stderr]}"
        break
      end

      result = run "git -C '#{dir}' checkout #{head_sha}"
      unless result[:exit_code] == 0
        logger.info "Unable to checkout commit #{head_sha} - it probably doesn't exist any more in the repository..."
        logger.info "stderr: #{result[:stderr]}"
        break
      end

      result = run "git -C '#{dir}' diff #{range} --name-only -- _data/projects/"
      unless result[:exit_code] == 0
        logger.info "Unable to compute diff range: #{range}..."
        logger.info "stderr: #{result[:stderr]}"
      end

      raw_files = result[:stdout].split("\n")

      files = raw_files.map(&:chomp)

      if files.empty?
        logger.info "No project files have been included in this PR..."
        break
      end

      logger.info "Found files in this PR to process: '#{files}'"
    end

  end

  def run(cmd)
    logger.info "Running command: #{cmd}"
    stdout, stderr, status = Open3.capture3(cmd)

    {
      stdout: stdout,
      stderr: stderr,
      exit_code: status.exitstatus,
    }
  end
end
