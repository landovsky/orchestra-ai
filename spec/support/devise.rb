module RequestSpecHelper
  def sign_in(user)
    # Manually sign in the user for request specs
    post user_session_path, params: {
      user: {
        email: user.email,
        password: user.password || 'password123'
      }
    }
  end

  def sign_out(user)
    delete destroy_user_session_path
  end
end

module ControllerSpecHelper
  def sign_in(user)
    # For controller specs, set up the mapping and sign in
    @request.env["devise.mapping"] = Devise.mappings[:user] if @request
    # Use Warden test mode
    Warden.test_mode!
    login_as(user, scope: :user)
  end

  def sign_out(user)
    # Clear the warden user
    @request.env['warden'].logout if @request && @request.env['warden']
    Warden.test_reset!
  end

  def login_as(resource, opts = {})
    scope = opts.fetch(:scope, :user)
    @request.env['warden'].set_user(resource, scope: scope) if @request
  end
end

RSpec.configure do |config|
  config.include RequestSpecHelper, type: :request
  config.include Devise::Test::ControllerHelpers, type: :controller
  config.include ControllerSpecHelper, type: :controller
  config.include Rails::Controller::Testing::TestProcess, type: :controller
  config.include Rails::Controller::Testing::TemplateAssertions, type: :controller
  config.include Rails::Controller::Testing::Integration, type: :controller

  config.after(:each, type: :controller) do
    Warden.test_reset!
  end
end
