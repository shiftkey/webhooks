# frozen_string_literal: true

Rails.application.routes.draw do
  root 'welcome#index'
  post '/:project/events', to: 'webhooks#receive'
end
