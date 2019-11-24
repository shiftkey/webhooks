# frozen_string_literal: true

class WebhooksController < ApplicationController
  protect_from_forgery with: :null_session

  def receive
    event = request.headers['X-GitHub-Event']
    project = params[:project]

    verify_signature

    payload = params[:payload]

    job = JobLocator.find_job_for_event(event, payload)

    if job
      job.perform_later(payload)
    else
      logger.info "No handler available for event type '#{event}' and project '#{project}'"
    end

    head :no_content
  end

  def verify_signature
    theirs = request.headers['HTTP_X_HUB_SIGNATURE']
    body = request.body.read
    raise 'Unable to verify signature of received payload' unless ENV['WEBHOOKS_SECRET_TOKEN']

    ours = 'sha1=' + OpenSSL::HMAC.hexdigest(OpenSSL::Digest.new('sha1'), ENV['WEBHOOKS_SECRET_TOKEN'], body)
    raise "Signatures didn't match!" unless Rack::Utils.secure_compare(theirs, ours)
  end
end
