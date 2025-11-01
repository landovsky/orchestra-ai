# frozen_string_literal: true

# AuthenticatedController serves as the base controller for all authenticated pages
# It requires user authentication and uses the authenticated layout with navbar
class AuthenticatedController < ApplicationController
  before_action :authenticate_user!
  layout 'authenticated'
end
