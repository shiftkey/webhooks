class WebhooksController < ApplicationController
  protect_from_forgery with: :null_session

  def receive
    event = request.headers['X-GitHub-Event']
    project = params[:project]

    logger.info "Received event type '#{event}' for project '#{project}' at '#{Time.now}'"

    signature = request.headers['HTTP_X_HUB_SIGNATURE']
    body = request.body.read()
    verify_signature(body, signature)

    decoded = URI.decode_www_form(body)
    json = JSON.parse(decoded)
    payload = json[:payload]

    payload_string = payload.to_s

    case event
    when 'pull_request'
      PullRequestJob.perform_later(payload_string)
    when 'ping'
      PingJob.perform_later(payload_string)
    else
      logger.info "No handler available for event type '#{event}' and project '#{project}'"
    end

    :ok
  end

  def verify_signature(payload_body, theirs)
    signature = 'sha1=' + OpenSSL::HMAC.hexdigest(OpenSSL::Digest.new('sha1'), ENV['WEBHOOKS_SECRET_TOKEN'], payload_body)
    raise "Signatures didn't match!" unless Rack::Utils.secure_compare(signature, theirs)
  end
end
