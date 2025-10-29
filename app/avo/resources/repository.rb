class Avo::Resources::Repository < Avo::BaseResource
  self.title = :name
  self.includes = [:user, :github_credential]
  
  # Fields
  def fields
    field :id, as: :id, link_to_record: true
    field :name, as: :text, required: true
    field :github_url, as: :text, required: true, help: "Full GitHub repository URL"
    field :created_at, as: :date_time, readonly: true
    field :updated_at, as: :date_time, readonly: true
    
    # Associations
    field :user, as: :belongs_to
    field :github_credential, as: :belongs_to, polymorphic_as: :credential, help: "Select a GitHub credential"
    field :epics, as: :has_many
  end
  
  # Filters
  def filters
    []
  end
  
  # Actions
  def actions
    []
  end
end
