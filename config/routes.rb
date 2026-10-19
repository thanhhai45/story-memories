Rails.application.routes.draw do
  # Kamal / load balancer health check
  get "up" => "rails/health#show", as: :rails_health_check

  root "memories#index"

  resources :memories do
    resources :photos, only: %i[create update destroy], controller: "memory_photos" do
      patch :reorder, on: :collection
    end
    resource :story, only: %i[show create update], controller: "memory_stories"
    resources :video_renders, only: %i[create show]
    resource :sharing, only: %i[create destroy], controller: "memory_sharings" do
      patch :rotate
    end
  end

  # Trang chia sẻ công khai: token ngẫu nhiên, không dùng ID tuần tự
  get "/s/:token", to: "shared_memories#show", as: :shared_memory,
                   constraints: { token: /[A-Za-z0-9_\-]{16,64}/ }
end
