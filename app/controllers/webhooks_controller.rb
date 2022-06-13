# frozen_string_literal: true

class WebhooksController < ApplicationController
  protect_from_forgery with: :null_session

  def receive
    event = request.headers['X-GitHub-Event']
    project = params[:project]

    logger.info "Received event '#{event}' for project '#{project}'"

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
    token = ENV.fetch('WEBHOOKS_SECRET_TOKEN', nil)
    raise 'Unable to verify signature of received payload' unless token

    ours = "sha1=#{OpenSSL::HMAC.hexdigest(OpenSSL::Digest.new('sha1'), token, body)}"
    raise "Signatures didn't match!" unless Rack::Utils.secure_compare(theirs, ours)
  end
end
