Rails.application.routes.draw do
  namespace :api do
    namespace :v1 do
      resources :categories, only: %i[index show create update destroy]
      resources :products, only: %i[index show create update destroy]
      resources :orders, only: %i[index show create update]
    end
  end
  get "/openapi.yaml", to: proc { |_env| [200, { "Content-Type" => "text/yaml" }, [File.read(Rails.root.join("docs/openapi.yaml"))]] }
  get "/docs", to: proc { |_env| [200, { "Content-Type" => "text/html" }, [File.read(Rails.root.join("docs/swagger.html"))]] }
  get "/up", to: "rails/health#show", as: :rails_health_check
end
