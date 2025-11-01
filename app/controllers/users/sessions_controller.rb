# frozen_string_literal: true

module Users
  # SessionsController overrides Devise's default sessions controller
  # to use the base layout (without navbar) for unauthenticated views
  class SessionsController < Devise::SessionsController
    layout 'base'

    # GET /users/sign_in
    # def new
    #   super
    # end

    # POST /users/sign_in
    # def create
    #   super
    # end

    # DELETE /users/sign_out
    # def destroy
    #   super
    # end

    # protected

    # If you have extra params to permit, append them to the sanitizer.
    # def configure_sign_in_params
    #   devise_parameter_sanitizer.permit(:sign_in, keys: [:attribute])
    # end
  end
end
