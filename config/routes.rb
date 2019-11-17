Rails.application.routes.draw do
  root 'welcome#index'
  post '/:action/events', to: 'webhooks#receive'
end
