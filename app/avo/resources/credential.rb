class Avo::Resources::Credential < Avo::BaseResource
  self.title = :name
  self.includes = [:user]
  
  # Fields
  def fields
    field :id, as: :id, link_to_record: true
    field :name, as: :text, required: true
    field :service_name, as: :text, required: true, help: "e.g., 'github', 'cursor', 'openai', 'anthropic'"
    field :api_key, as: :password, required: true, help: "Encrypted in database"
    field :created_at, as: :date_time, readonly: true
    field :updated_at, as: :date_time, readonly: true
    
    # Associations
    field :user, as: :belongs_to
  end
  
  # Filters
  def filters
    filter Avo::Filters::ServiceNameFilter
  end
  
  # Actions
  def actions
    []
  end
end
