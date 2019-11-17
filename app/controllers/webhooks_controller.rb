class WebhooksController < ApplicationController
  def receive
    event = request.headers['X-GitHub-Event']
    action = params[:action]
    logger.info "Received event type '#{event}' for action #{action} at '#{Time.now}'"
    :ok
  end

  def verify_signature(payload_body)
    signature = 'sha1=' + OpenSSL::HMAC.hexdigest(OpenSSL::Digest.new('sha1'), ENV['WEBHOOKS_SECRET_TOKEN'], payload_body)
    return halt 500, "Signatures didn't match!" unless Rack::Utils.secure_compare(signature, request.env['HTTP_X_HUB_SIGNATURE'])
  end
end
