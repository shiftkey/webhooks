# frozen_string_literal: true

require 'test_helper'

class UpForGrabsPullRequestProjectAnalyzerJobTest < ActiveJob::TestCase
  test 'can perform job using event' do
    head_clone_url = 'https://github.com/shiftkey/up-for-grabs.net'
    base_clone_url = 'https://github.com/up-for-grabs/up-for-grabs.net'

    head_sha = 'some-sha-432907752395735'
    base_sha = 'different-sha-35643dsgdgd6464364'

    range = "#{base_sha}...#{head_sha}"

    payload = {
      action: 'opened',
      number: 1,
      pull_request: {
        base: {
          ref: 'gh-pages',
          repo: {
            default_branch: 'gh-pages',
            clone_url: base_clone_url
          },
          sha: base_sha
        },
        head: {
          sha: head_sha,
          repo: {
            default_branch: 'gh-pages',
            clone_url: head_clone_url
          }
        }
      },
      repository: {
        full_name: 'up-for-grabs/up-for-grabs.net'
      }
    }

    dir = get_test_directory('valid-project-files')

    Dir
      .expects(:mktmpdir)
      .yields(dir)

    UpForGrabsPullRequestProjectAnalyzerJob
      .any_instance
      .expects(:run)
      .with("git clone -- '#{head_clone_url}' '#{dir}'")
      .returns({
                 exit_code: 0
               })

    UpForGrabsPullRequestProjectAnalyzerJob
      .any_instance
      .expects(:run)
      .with("git -C '#{dir}' remote add upstream '#{base_clone_url}' -f")
      .returns({
                 exit_code: 0
               })

    UpForGrabsPullRequestProjectAnalyzerJob
      .any_instance
      .expects(:run)
      .with("git -C '#{dir}' checkout #{head_sha}")
      .returns({
                 exit_code: 0
               })

    files = get_files_in_directory('valid-project-files').join("\n")

    UpForGrabsPullRequestProjectAnalyzerJob
      .any_instance
      .expects(:run)
      .with("git -C '#{dir}' diff #{range} --name-only -- _data/projects/")
      .returns({
                 exit_code: 0,
                 stdout: files
               })

    UpForGrabsPullRequestProjectAnalyzerJob
      .any_instance
      .expects(:create_client)
      .returns({})

    UpForGrabsPullRequestProjectAnalyzerJob
      .any_instance
      .expects(:cleanup_old_comments)
      .returns(false)

    UpForGrabsPullRequestProjectAnalyzerJob
      .any_instance
      .expects(:add_comment_to_pull_request)
      .returns(nil)

    UpForGrabsPullRequestProjectAnalyzerJob.perform_now payload.to_json
  end

  def get_test_directory(name)
    parent = File.dirname(__dir__)
    Pathname.new("#{parent}/fixtures/pull_requests/#{name}")
  end

  def get_files_in_directory(name)
    parent = File.dirname(__dir__)
    root = "#{parent}/repositories/pull_requests/#{name}"
    Dir.chdir(root) { Dir.glob('_data/projects/*').select { |path| File.file?(path) } }.sort
  end
end
