class Avo::Resources::User < Avo::BaseResource
  self.title = :email
  self.includes = []
  
  # Fields
  def fields
    field :id, as: :id, link_to_record: true
    field :email, as: :text, required: true
    field :created_at, as: :date_time, readonly: true
    field :updated_at, as: :date_time, readonly: true
    
    # Associations
    field :credentials, as: :has_many
    field :repositories, as: :has_many
    field :epics, as: :has_many
    field :notification_channels, as: :has_many
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
