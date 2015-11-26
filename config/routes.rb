Rails.application.routes.draw do
  scope :v1 do
    resources :districts, except: [:new, :edit] do
      member do
        post :launch_instances
        post :terminate_instance
      end

      resources :plugins, except: [:new, :edit]
      resources :elastic_ips, only: [:index, :create]

      resources :heritages, shallow: true, except: [:new, :edit] do
        post   :env_vars, on: :member, to: "heritages#set_env_vars"
        delete :env_vars, on: :member, to: "heritages#delete_env_vars"

        post "/services/:service_id/scale", to: "services#scale"
        post "/trigger/:token", to: "heritages#trigger"
        resources :oneoffs, only: [:show, :create]
      end
    end

    resources :users, only: [:index, :show, :update]

    post "/login", to: "users#login"
    patch "/user", to: "users#update"
    get "/user", to: "users#show"
  end
end
