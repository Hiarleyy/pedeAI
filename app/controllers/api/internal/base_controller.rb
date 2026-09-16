module Api
  module Internal
    class BaseController < ApplicationController
      include PlatformAuthenticatable
      before_action :authenticate_platform_user!
    end
  end
end
