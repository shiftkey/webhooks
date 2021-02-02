# frozen_string_literal: true

require 'test_helper'

class WebhooksControllerTest < ActionDispatch::IntegrationTest
  test 'ping event is scheduled' do
    assert_enqueued_with(job: PingJob) do
      payload = load_fixture_as_www_encoded_form('ping-up-for-grabs')

      post '/up-for-grabs/events',
           params: payload,
           headers: headers('ping', payload)

      assert_response 204
    end
  end

  test 'pull request event is scheduled' do
    assert_enqueued_with(job: UpForGrabsPullRequestProjectAnalyzerJob) do
      payload = load_fixture_as_www_encoded_form('pull-request-opened-up-for-grabs-1715')

      post '/up-for-grabs/events',
           params: payload,
           headers: headers('pull_request', payload)

      assert_response 204
    end
  end

  test 'invalid pull request event is ignored' do
    payload = load_fixture_as_www_encoded_form('pull-request-opened-shiftkey-webhooks')

    post '/webhooks/events',
         params: payload,
         headers: headers('pull_request', payload)

    assert_response 204
    assert_no_enqueued_jobs
  end

  def signature(payload)
    OpenSSL::HMAC.hexdigest(OpenSSL::Digest.new('sha1'), ENV['WEBHOOKS_SECRET_TOKEN'], payload)
  end

  def load_fixture_as_www_encoded_form(name)
    parent = File.dirname(__dir__)
    full_path = Pathname.new("#{parent}/fixtures/events/#{name}.json")
    json = File.read(full_path)
    URI.encode_www_form([['payload', json]])
  end

  def headers(event, payload)
    {
      'X-GitHub-Event': event,
      'Content-Type': 'application/x-www-form-urlencoded',
      HTTP_X_HUB_SIGNATURE: "sha1=#{signature(payload)}"
    }
  end
end
