# frozen_string_literal: true

class UpForGrabsPullRequestProjectAnalyzerJob < ApplicationJob
  queue_as :default

  PREAMBLE_HEADER = '<!-- PULL REQUEST ANALYZER GITHUB ACTION -->'

  def self.can_process(payload)
    obj = JSON.parse(payload)

    action = obj['action']
    base = obj['pull_request']['base']
    repo = obj['repository']

    return false unless %w[synchronize opened reopened].include?(action)

    return false unless repo['full_name'] == 'up-for-grabs/up-for-grabs.net'

    return false unless base['ref'] == base['repo']['default_branch']

    true
  end

  def perform(payload)
    obj = JSON.parse(payload)

    pull_request_number = obj['number']

    pull_request = obj['pull_request']
    base = pull_request['base']
    head = pull_request['head']
    subject_id = pull_request['node_id']

    base_sha = base['sha']
    head_sha = head['sha']

    base_repo = base['repo']
    head_repo = head['repo']

    repo = base_repo['full_name']

    head_clone_url = head_repo['clone_url']
    base_clone_url = base_repo['clone_url']

    range = "#{base_sha}...#{head_sha}"

    Dir.mktmpdir do |dir|
      result = run "git clone -- '#{head_clone_url}' '#{dir}'"

      unless result[:exit_code].zero?
        logger.info "Unable to clone repository at #{head_clone_url} - check that you can access it..."
        logger.info "stderr: #{result[:stderr]}"
        break
      end

      if head_clone_url != base_clone_url
        result = run "git -C '#{dir}' remote add upstream '#{base_clone_url}' -f"

        unless result[:exit_code].zero?
          logger.info "Unable to clone repository at #{base_clone_url} - check that you can access it..."
          logger.info "stderr: #{result[:stderr]}"
          break
        end
      end

      result = run "git -C '#{dir}' checkout #{head_sha}"
      unless result[:exit_code].zero?
        logger.info "Unable to checkout commit #{head_sha} - it probably doesn't exist any more in the repository..."
        logger.info "stderr: #{result[:stderr]}"
        break
      end

      result = run "git -C '#{dir}' diff #{range} --name-only -- _data/projects/"
      unless result[:exit_code].zero?
        logger.info "Unable to compute diff range: #{range}..."
        logger.info "stderr: #{result[:stderr]}"
      end

      raw_files = result[:stdout].split("\n")

      files = raw_files.map(&:chomp)

      if files.empty?
        logger.info 'No project files have been included in this PR...'
        break
      end

      logger.info "Found files in this PR to process: '#{files}'"

      client = create_client

      comment_deleted = cleanup_old_comments(client, repo, pull_request_number)

      markdown_body = PullRequestValidator.generate_comment(dir, files, initial_message: !comment_deleted)

      logger.info "Comment to submit: #{markdown_body}"

      add_comment_to_pull_request(client, subject_id, markdown_body)
    end
  end

  def create_client
    http = GraphQL::Client::HTTP.new('https://api.github.com/graphql') do
      def headers(_context)
        {
          "User-Agent": 'up-for-grabs-graphql-label-queries',
          "Authorization": "bearer #{ENV['SHIFTBOT_GITHUB_TOKEN']}"
        }
      end
    end

    schema = GraphQL::Client.load_schema(http)

    GraphQL::Client.new(schema: schema, execute: http)
  end

  def run(cmd)
    logger.info "Running command: #{cmd}"
    stdout, stderr, status = Open3.capture3(cmd)

    {
      stdout: stdout,
      stderr: stderr,
      exit_code: status.exitstatus
    }
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

    return false unless comments.nodes.any?

    Object.const_set :DeleteIssueComment, client.parse(<<-'GRAPHQL')
      mutation ($input: DeleteIssueCommentInput!) {
        deleteIssueComment(input: $input)
      }
    GRAPHQL

    login = 'shiftbot'
    type = 'User'

    comments.nodes.each do |node|
      author = node.author
      match = author.login == login && author.__typename == type && node.body.include?(PREAMBLE_HEADER)

      next unless match

      variables = { input: { id: node.id } }
      response = client.query(DeleteIssueComment, variables: variables)

      if response.errors.any?
        message = response.errors[:data].join(', ')
        logger.info "Message when deleting commit failed: #{message}"
      end
    end

    true
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
