Rails.application.routes.draw do
  namespace :api do
    namespace :v1 do
      resources :categories, only: %i[index show create update destroy]
      resources :products, only: %i[index show create update destroy]
      resources :orders, only: %i[index show create update]
      resource :session, only: :create
      resources :restaurants, only: %i[index show create update]
      resources :restaurants, only: [] do
        resources :users, only: %i[index create destroy]
      end
      resources :users, only: :update
      scope "restaurants/:restaurant_slug" do
        get "categories", to: "categories#index"
        post "categories", to: "categories#create"
        get "categories/:id", to: "categories#show"
        patch "categories/:id", to: "categories#update"
        delete "categories/:id", to: "categories#destroy"
        get "products", to: "products#index"
        post "orders", to: "orders#create"
        get "orders", to: "orders#index"
        patch "orders/:id", to: "orders#update"
        get "products/:id", to: "products#show"
        post "products", to: "products#create"
        patch "products/:id", to: "products#update"
        delete "products/:id", to: "products#destroy"
        get "users", to: "users#index"
        post "users", to: "users#create"
        patch "users/:id", to: "users#update"
        delete "users/:id", to: "users#destroy"
      end

    end
  end
  get "/openapi.yaml", to: proc { |_env| [200, { "Content-Type" => "text/yaml" }, [File.read(Rails.root.join("docs/openapi.yaml"))]] }
  get "/docs", to: proc { |_env| [200, { "Content-Type" => "text/html" }, [File.read(Rails.root.join("docs/swagger.html"))]] }
  get "/admin", to: proc { |_env| [200, { "Content-Type" => "text/html; charset=utf-8" }, [File.read(Rails.root.join("docs/admin.html"))]] }
  get "/admin/:restaurant_slug", to: "pages#admin"
  root to: proc { |_env| [200, { "Content-Type" => "text/html; charset=utf-8" }, [File.read(Rails.root.join("docs/pagina-inicial.html"))]] }
  get "/cardapio", to: proc { |_env| [200, { "Content-Type" => "text/html; charset=utf-8" }, [File.read(Rails.root.join("docs/menu.html"))]] }
  get "/cardapio/:restaurant_slug", to: "pages#menu"
  get "/up", to: "rails/health#show", as: :rails_health_check
end

