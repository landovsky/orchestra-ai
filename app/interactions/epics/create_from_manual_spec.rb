module Epics
  class CreateFromManualSpec < ActiveInteraction::Base
    object :user, class: User
    object :repository, class: Repository
    string :tasks_json
    string :base_branch, default: 'main'
    integer :cursor_agent_credential_id, default: nil

    validates :tasks_json, presence: true
    validate :validate_tasks_json_format
    validate :validate_cursor_agent_credential, if: -> { cursor_agent_credential_id.present? }

    def execute
      ActiveRecord::Base.transaction do
        # Create the Epic
        epic = Epic.create!(
          user: user,
          repository: repository,
          title: generate_title,
          prompt: "Manual spec with #{parsed_tasks.size} tasks",
          base_branch: base_branch,
          cursor_agent_credential_id: cursor_agent_credential_id,
          status: :pending
        )

        # Create Tasks with positions
        tasks = parsed_tasks.each_with_index.map do |task_description, index|
          Task.create!(
            epic: epic,
            description: task_description,
            position: index
          )
        end

        # Return both epic and tasks
        { epic: epic, tasks: tasks }
      end
    end

    private

    def parsed_tasks
      @parsed_tasks ||= JSON.parse(tasks_json)
    rescue JSON::ParserError => e
      errors.add(:tasks_json, "must be valid JSON: #{e.message}")
      []
    end

    def validate_tasks_json_format
      return if errors[:tasks_json].any?

      unless parsed_tasks.is_a?(Array)
        errors.add(:tasks_json, 'must be a JSON array')
        return
      end

      if parsed_tasks.empty?
        errors.add(:tasks_json, 'must contain at least one task')
        return
      end

      parsed_tasks.each_with_index do |task, index|
        unless task.is_a?(String)
          errors.add(:tasks_json, "task at index #{index} must be a string")
        end

        if task.is_a?(String) && task.strip.empty?
          errors.add(:tasks_json, "task at index #{index} cannot be blank")
        end
      end
    end

    def validate_cursor_agent_credential
      credential = Credential.find_by(id: cursor_agent_credential_id, user: user)
      
      if credential.nil?
        errors.add(:cursor_agent_credential_id, 'must belong to the user')
      elsif credential.service_name != 'cursor_agent'
        errors.add(:cursor_agent_credential_id, 'must be a cursor_agent credential')
      end
    end

    def generate_title
      first_task = parsed_tasks.first
      if first_task.length > 50
        "#{first_task[0..47]}..."
      else
        first_task
      end
    end
  end
end
