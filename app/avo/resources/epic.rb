class Avo::Resources::Epic < Avo::BaseResource
  self.title = :title
  self.includes = [:user, :repository, :tasks]
  
  # Fields
  def fields
    field :id, as: :id, link_to_record: true
    field :title, as: :text, required: true
    field :status, as: :select, 
          enum: ::Epic.statuses,
          display_with_value: true,
          required: true
    field :base_branch, as: :text, help: "e.g., 'main' or 'master'"
    field :prompt, as: :textarea, help: "LLM prompt for generating spec"
    field :created_at, as: :date_time, readonly: true
    field :updated_at, as: :date_time, readonly: true
    
    # Associations
    field :user, as: :belongs_to
    field :repository, as: :belongs_to
    field :llm_credential, as: :belongs_to, polymorphic_as: :credential, optional: true
    field :cursor_agent_credential, as: :belongs_to, polymorphic_as: :credential, optional: true
    field :tasks, as: :has_many
  end
  
  # Filters
  def filters
    filter Avo::Filters::StatusFilter
  end
  
  # Actions
  def actions
    []
  end
end
