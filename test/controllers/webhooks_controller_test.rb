# frozen_string_literal: true

require 'test_helper'

class WebhooksControllerTest < ActionDispatch::IntegrationTest
  test 'ping event is scheduled' do
    assert_enqueued_with(job: PingJob) do
      payload = load_fixture('ping-up-for-grabs')

      ENV['WEBHOOKS_SECRET_TOKEN'] = 'foo'

      post '/up-for-grabs/events',
           params: {
             payload: payload
           },
           headers: {
             'X-GitHub-Event': 'ping',
             # TODO: this is hard-coded for now, but should be computed on the fly
             'HTTP_X_HUB_SIGNATURE': 'sha1=d482d75e17a3ca1dc81080b030cfc448831ccf18'
           }

      assert_response 204
    end
  end

  test 'pull request event is scheduled' do
    assert_enqueued_with(job: PullRequestJob) do
      payload = load_fixture('pull-request-opened-up-for-grabs-1715')

      ENV['WEBHOOKS_SECRET_TOKEN'] = 'foo'

      post '/up-for-grabs/events',
           params: {
             payload: payload
           },
           headers: {
             'X-GitHub-Event': 'pull_request',
             # TODO: this is hard-coded for now, but should be computed on the fly
             'HTTP_X_HUB_SIGNATURE': 'sha1=6c81a11a317fd5130b9f174113672f7f5e8e5070'
           }

      assert_response 204
    end
  end

  def load_fixture(name)
    parent = File.dirname(__dir__)
    full_path = Pathname.new("#{parent}/fixtures/events/#{name}.json")
    File.read(full_path)
  end
end
