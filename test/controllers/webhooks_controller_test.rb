# frozen_string_literal: true

require 'test_helper'

# TODO: how can we emulate request.body.read to compute the correct signatures?
# TODO: compute checksums on the fly and assign to headers

class WebhooksControllerTest < ActionDispatch::IntegrationTest
  test 'ping event is scheduled' do
    assert_enqueued_with(job: PingJob) do
      payload = load_fixture('ping-up-for-grabs')

      post '/up-for-grabs/events',
           params: {
             payload: payload
           },
           headers: {
             'X-GitHub-Event': 'ping',
             'HTTP_X_HUB_SIGNATURE': 'sha1=d482d75e17a3ca1dc81080b030cfc448831ccf18'
           }

      assert_response 204
    end
  end

  test 'pull request event is scheduled' do
    assert_enqueued_with(job: PullRequestJob) do
      payload = load_fixture('pull-request-opened-up-for-grabs-1715')

      post '/up-for-grabs/events',
           params: {
             payload: payload
           },
           headers: {
             'X-GitHub-Event': 'pull_request',
             'HTTP_X_HUB_SIGNATURE': 'sha1=6c81a11a317fd5130b9f174113672f7f5e8e5070'
           }

      assert_response 204
    end
  end

  test 'invalid pull request event is ignored' do
    payload = load_fixture('pull-request-opened-shiftkey-webhooks')

    post '/webhooks/events',
          params: {
            payload: payload
          },
          headers: {
            'X-GitHub-Event': 'pull_request',
            'HTTP_X_HUB_SIGNATURE': 'sha1=a438da7a055b21a5338a0083e1a934dc5198c26d'
          }

    assert_response 204
    assert_no_enqueued_jobs
  end

  def load_fixture(name)
    parent = File.dirname(__dir__)
    full_path = Pathname.new("#{parent}/fixtures/events/#{name}.json")
    File.read(full_path)
  end
end
