Rails.application.routes.draw do
  get "/favicon.ico", to: proc { |_env| [204, { "Cache-Control" => "public, max-age=86400" }, []] }

  namespace :api do
    namespace :v1 do
      resource :session, only: :create
      post "restaurants", to: "restaurants#create"

      scope "restaurants/:restaurant_slug" do
        get "", to: "restaurants#show"
        patch "", to: "restaurants#update"
        resources :categories, only: %i[index show create update destroy]
        resources :products, only: %i[index show create update destroy]
        post "menu-import", to: "menu_imports#create"
        get "orders/track", to: "orders#track"
        resources :orders, only: %i[index show create update]
        resources :users, only: %i[index create update destroy]
      end
    end
  end

  get "/openapi.yaml", to: proc { |_env| [200, { "Content-Type" => "text/yaml; charset=utf-8" }, [File.read(Rails.root.join("docs/openapi.yaml"))]] }
  get "/menu-import-template.json", to: proc { |_env| [200, { "Content-Type" => "application/json; charset=utf-8", "Content-Disposition" => "attachment; filename=cardapio-modelo-v1.json" }, [File.read(Rails.root.join("docs/menu-import-template.json"))]] }
  get "/docs", to: proc { |_env| [200, { "Content-Type" => "text/html; charset=utf-8" }, [File.read(Rails.root.join("docs/swagger.html"))]] }
  get "/admin", to: proc { |_env| [200, { "Content-Type" => "text/html; charset=utf-8" }, [File.read(Rails.root.join("docs/admin.html"))]] }
  get "/admin/:restaurant_slug", to: "pages#admin"
  root to: proc { |_env| [200, { "Content-Type" => "text/html; charset=utf-8" }, [File.read(Rails.root.join("docs/pagina-inicial.html"))]] }
  get "/cardapio", to: proc { |_env| [200, { "Content-Type" => "text/html; charset=utf-8" }, [File.read(Rails.root.join("docs/menu.html"))]] }
  get "/cardapio/:restaurant_slug", to: "pages#menu"
  get "/up", to: "rails/health#show", as: :rails_health_check
end
