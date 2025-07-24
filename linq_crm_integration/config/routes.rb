Rails.application.routes.draw do
  # Health check endpoint for load balancers and monitoring
  get "up" => "rails/health#show", as: :rails_health_check

  # API versioning namespace
  namespace :api do
    namespace :v1 do
      # Authentication endpoints
      post "auth/login", to: "auth#login"
      post "auth/validate", to: "auth#validate"

      # Contact management endpoints
      resources :contacts, only: [:index, :create] do
        collection do
          get :sync, action: :index, defaults: { sync_with_acme: true }
          post :bulk, action: :bulk_create
        end
      end
    end
  end

  # API documentation (when implemented)
  # mount Rswag::Ui::Engine => '/api-docs'
  # mount Rswag::Api::Engine => '/api-docs'

  # Root route for API information
  root to: proc {
    [200, { "Content-Type" => "application/json" }, [{
      service: "Linq CRM Integration API",
      version: "1.0.0",
      description: "API for integrating Linq with AcmeCRM",
      endpoints: {
        health: "/up",
        auth: {
          login: "POST /api/v1/auth/login",
          validate: "POST /api/v1/auth/validate"
        },
        contacts: {
          list: "GET /api/v1/contacts",
          create: "POST /api/v1/contacts",
          bulk_create: "POST /api/v1/contacts/bulk",
          sync: "GET /api/v1/contacts/sync"
        }
      },
      documentation: "See README.md for detailed usage instructions"
    }.to_json]]
  }
end
