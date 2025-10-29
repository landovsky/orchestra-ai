class Avo::Resources::NotificationChannel < Avo::BaseResource
  self.title = :id
  self.includes = [:user]
  
  # Fields
  def fields
    field :id, as: :id, link_to_record: true
    field :service_name, as: :text, required: true, help: "e.g., 'telegram', 'slack'"
    field :channel_id, as: :text, required: true, help: "Chat ID or channel identifier"
    field :created_at, as: :date_time, readonly: true
    field :updated_at, as: :date_time, readonly: true
    
    # Associations
    field :user, as: :belongs_to
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
