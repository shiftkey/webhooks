# frozen_string_literal: true

require_relative '../../lib/job_locator'

class JobLocatorTest < MiniTest::Test
  def test_status_event_returns_nil
    assert_nil JobLocator.find_job_for_event('status', '{}')
  end

  def test_ping_event_returns_job
    refute_nil JobLocator.find_job_for_event('ping', '{}')
  end

  def test_pull_request_open_for_targeted_repository_returns_job
    payload = load_fixture('pull-request-opened-up-for-grabs-1715')
    refute_nil JobLocator.find_job_for_event('pull_request', payload)
  end

  def test_pull_request_open_for_different_repository_returns_nil
    payload = load_fixture('pull-request-opened-shiftkey-webhooks')
    assert_nil JobLocator.find_job_for_event('pull_request', payload)
  end

  def test_pull_request_closed_for_targeted_repository_returns_nil
    payload = load_fixture('pull-request-closed-up-for-grabs-1715')
    assert_nil JobLocator.find_job_for_event('pull_request', payload)
  end

  def test_pull_request_targeted_repository_wrong_base_returns_nil
    payload = load_fixture('pull-request-opened-up-for-grabs-1716')
    assert_nil JobLocator.find_job_for_event('pull_request', payload)
  end

  def load_fixture(name)
    parent = File.dirname(__dir__)
    full_path = Pathname.new("#{parent}/fixtures/events/#{name}.json")
    File.read(full_path)
  end
end
