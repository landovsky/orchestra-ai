Avo.configure do |config|
  ## == Routing ==
  config.root_path = '/avo'
  
  ## == Licensing ==
  config.license = 'community' # change this to pro when you get a license
  config.license_key = ENV['AVO_LICENSE_KEY']

  ## == Set the context ==
  config.set_context do
    {
      foo: 'bar',
      current_user: current_user,
      tenant: current_user&.tenant
    }
  end

  ## == Authentication ==
  config.authenticate = lambda { |request|
    # Require user to be authenticated with Devise
    authenticate_user!(request)
  }

  ## == Authorization ==
  config.authorize = lambda { |request|
    # Add authorization logic here if needed
    # For now, allow all authenticated users
    true
  }

  ## == Current User ==
  config.current_user_method = :current_user

  ## == Localization ==
  config.locale = :en

  ## == Resource Default ==
  config.resource_default_view = :show
  config.buttons_on_form_footers = true
  config.pagination = {
    type: :default,
    size: [20, 50, 100]
  }

  ## == Model Resource Mapping ==
  # config.model_resource_mapping = {}

  ## == Breadcrumbs ==
  config.display_breadcrumbs = true
  config.set_initial_breadcrumbs do
    add_breadcrumb "Home", '/avo'
  end
end
