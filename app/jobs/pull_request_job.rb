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
    head_repo = head['repo']
    default_branch = base_repo['default_branch']

    repo = base_repo['full_name']

    logger.info "Action '#{obj['action']}' for PR ##{pull_request_number} on repo '#{repo}'"

    unless action == 'synchronize' || action == 'opened' || action == 'reopened'
      logger.info "Pull request action #{action} is not handled. Ignoring..."
      return
    end

    unless base_ref == default_branch
      logger.info "Pull request targets '#{base_ref}' rather than the default branch '#{default_branch}'. Ignoring..."
      return
    end

    head_clone_url = head_repo['clone_url']
    base_clone_url = base_repo['clone_url']

    range = "#{base_sha}...#{head_sha}"

    Dir.mktmpdir do |dir|
      result = run "git clone -- '#{head_clone_url}' '#{dir}'"

      unless result[:exit_code] == 0
        logger.info "Unable to clone repository at #{head_clone_url} - check that you can access it..."
        logger.info "stderr: #{result[:stderr]}"
        break
      end

      if head_clone_url != base_clone_url
        result = run "git -C '#{dir}' remote add upstream '#{base_clone_url}' -f"

        unless result[:exit_code] == 0
          logger.info "Unable to clone repository at #{base_clone_url} - check that you can access it..."
          logger.info "stderr: #{result[:stderr]}"
          break
        end
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

      http = GraphQL::Client::HTTP.new('https://api.github.com/graphql') do
        def headers(_context)
          {
            "User-Agent": 'up-for-grabs-graphql-label-queries',
            "Authorization": "bearer #{ENV['SHIFTBOT_GITHUB_TOKEN']}"
          }
        end
      end

      schema = GraphQL::Client.load_schema(http)

      client = GraphQL::Client.new(schema: schema, execute: http)

      cleanup_old_comments(client, repo, pull_request_number)

      schema = Pathname.new("#{dir}/schema.json")
      schemer = JSONSchemer.schema(schema)

      projects = files.map do |f|
        full_path = File.join(dir, f)
        return nil unless File.exist?(full_path)

        Project.new(f, full_path)
      end

      markdown_body = generate_comment_for_pull_request(projects, schemer)

      logger.info "Comment to submit: #{markdown_body}"

      add_comment_to_pull_request(client, subject_id, markdown_body)
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

  def review_project(project, schemer)
    validation_errors = ProjectValidator.validate(project, schemer)

    return { project: project, kind: 'validation', validation_errors: validation_errors } if validation_errors.any?

    # TODO: label suggestions should be their own thing?

    return { project: project, kind: 'valid' } unless project.github_project?

    repository_error = repository_check(project)

    return { project: project, kind: 'repository', message: repository_error } unless repository_error.nil?

    label_error = label_check(project)

    return { project: project, kind: 'label', message: label_error } unless label_error.nil?

    { project: project, kind: 'valid' }
  end

  def cleanup_old_comments(client, repo, pull_request_number)
    Object.const_set :PullRequestComments, client.parse(<<-'GRAPHQL')
      query ($owner: String!, $name: String!, $number: Int!) {
        repository(owner: $owner, name: $name) {
          pullRequest(number: $number) {
            comments(first: 50) {
              nodes {
                id
                body
                author {
                  login
                  __typename
                }
              }
            }
          }
        }
      }
    GRAPHQL

    owner, name = repo.split('/')

    variables = { owner: owner, name: name, number: pull_request_number }

    response = client.query(PullRequestComments, variables: variables)

    pull_request = response.data.repository.pull_request
    comments = pull_request.comments

    return unless comments.nodes.any?

    Object.const_set :DeleteIssueComment, client.parse(<<-'GRAPHQL')
      mutation ($input: DeleteIssueCommentInput!) {
        deleteIssueComment(input: $input)
      }
    GRAPHQL

    login = 'shiftbot'
    type = 'User'
    preamble = '<!-- PULL REQUEST ANALYZER GITHUB ACTION -->'

    comments.nodes.each do |node|
      author = node.author
      match = author.login == login && author.__typename == type && node.body.include?(preamble)

      next unless match

      variables = { input: { id: node.id } }
      response = client.query(DeleteIssueComment, variables: variables)

      if response.errors.any?
        message = response.errors[:data].join(', ')
        logger.info "Message when deleting commit failed: #{message}"
      end
    end
  end

  def generate_comment_for_pull_request(projects, schemer)
    markdown_body = "<!-- PULL REQUEST ANALYZER GITHUB ACTION -->
    :wave: I'm a robot checking the state of this pull request to save the human reveiwers time." \
    " I noticed this PR added or modififed the data files under `_data/projects/` so I had a look at what's changed.\n\n" \
    "As you make changes to this pull request, I'll re-run these checks.\n\n"

    messages = projects.compact.map { |p| review_project(p, schemer) }.map do |result|
      path = result[:project].relative_path

      if result[:kind] == 'valid'
        "#### `#{path}` :white_check_mark: \nNo problems found, everything should be good to merge!"
      elsif result[:kind] == 'validation'
        message = result[:validation_errors].map { |e| "> - #{e}" }.join "\n"
        "#### `#{path}` :x:\nI had some troubles parsing the project file, or there were fields that are missing that I need.\n\nHere's the details:\n#{message}"
      elsif result[:kind] == 'repository' || result[:kind] == 'label'
        "#### `#{path}` :x:\n#{result[:message]}"
      else
        "#### `#{path}` :question:\nI got a result of type '#{result[:kind]}' that I don't know how to handle. I need to mention @shiftkey here as he might be able to fix it."
      end
    end

    markdown_body + messages.join("\n\n")
  end

  def add_comment_to_pull_request(client, subject_id, markdown_body)
    Object.const_set :AddCommentToPullRequest, client.parse(<<-'GRAPHQL')
      mutation ($input: AddCommentInput!) {
        addComment(input: $input) {
          commentEdge {
            node {
              url
            }
          }
        }
      }
    GRAPHQL

    variables = { input: { body: markdown_body, subjectId: subject_id } }

    begin
      response = client.query(AddCommentToPullRequest, variables: variables)

      if (data = response.data)
        if data.add_comment?
          comment = data.add_comment.comment_edge.node
          logger.info "A comment has been created at '#{comment.url}'"
        elsif data.errors
          logger.info 'Errors found in data from response:'
          data.errors.each { |field, error| logger.info " - '#{field}' - #{error}" }
        end
      end

      return unless response.errors.any?

      logger.info 'Errors found in response when trying to add comment:'
      response.errors.each { |field, error| logger.info " - '#{field}' - #{error}" }
    rescue StandardError => e
      logger.info "Unhandled exception occurred: #{e}"
    end
  end

end
