class Avo::Resources::Task < Avo::BaseResource
  self.title = :description
  self.includes = [:epic]
  
  # Fields
  def fields
    field :id, as: :id, link_to_record: true
    field :description, as: :textarea, required: true
    field :status, as: :select,
          enum: ::Task.statuses,
          display_with_value: true,
          required: true
    field :position, as: :number, required: true, min: 0, help: "Order within epic (0-based)"
    field :branch_name, as: :text
    field :cursor_agent_id, as: :text, help: "ID returned from Cursor API"
    field :pr_url, as: :text
    field :debug_log, as: :textarea, readonly: true
    field :created_at, as: :date_time, readonly: true
    field :updated_at, as: :date_time, readonly: true
    
    # Associations
    field :epic, as: :belongs_to
  end
  
  # Filters
  def filters
    filter Avo::Filters::TaskStatusFilter
  end
  
  # Actions
  def actions
    []
  end
end
