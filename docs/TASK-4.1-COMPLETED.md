# Task 4.1: Epics::CreateFromManualSpec Interaction - COMPLETED

## Overview
Created a working interaction class `Epics::CreateFromManualSpec` that creates an Epic with tasks from console input, with proper task positioning and comprehensive test coverage.

## Files Created

### 1. Interaction Class
**Location:** `app/interactions/epics/create_from_manual_spec.rb`

**Features:**
- Creates Epic with `pending` status
- Parses JSON array of task descriptions
- Creates Task records with sequential positions (0, 1, 2, ...)
- Validates JSON format and content
- Validates cursor_agent_credential ownership and type
- Generates title from first task (truncated if > 50 chars)
- Uses database transactions for atomicity
- Defaults base_branch to 'main'

**Inputs:**
- `user` (User object) - Required
- `repository` (Repository object) - Required
- `tasks_json` (String) - Required JSON array of task descriptions
- `base_branch` (String) - Optional, defaults to 'main'
- `cursor_agent_credential_id` (Integer) - Optional

**Returns:**
```ruby
{
  epic: Epic,      # The created Epic record
  tasks: [Task]    # Array of created Task records
}
```

**Validations:**
- tasks_json must be valid JSON
- tasks_json must be an array
- tasks_json must contain at least one task
- Each task must be a non-blank string
- cursor_agent_credential must belong to user (if provided)
- cursor_agent_credential must be of type 'cursor_agent' (if provided)

### 2. Test Spec
**Location:** `spec/interactions/epics/create_from_manual_spec_spec.rb`

**Test Coverage:**
- ✓ Creates epic with pending status
- ✓ Creates tasks with correct descriptions
- ✓ Creates tasks with correct positions (0, 1, 2, ...)
- ✓ Creates tasks in correct order in database
- ✓ Generates title from first task
- ✓ Truncates long titles (> 50 chars)
- ✓ Uses default base_branch when not provided
- ✓ Allows custom base_branch
- ✓ Fails with invalid JSON
- ✓ Fails when tasks_json is not an array
- ✓ Fails when tasks array is empty
- ✓ Fails when a task is not a string
- ✓ Fails when a task is blank
- ✓ Fails when cursor_agent_credential does not belong to user
- ✓ Fails when cursor_agent_credential is not cursor_agent type
- ✓ Fails when cursor_agent_credential_id does not exist
- ✓ Transaction rollback on failure
- ✓ Handles large task arrays (10+ tasks)

### 3. Manual Test Script
**Location:** `script/test_create_from_manual_spec.rb`

A standalone Ruby script for manual testing of the interaction. Run with:
```bash
./script/test_create_from_manual_spec.rb
```

Tests:
1. Basic creation with 3 tasks
2. Task position verification
3. Invalid JSON handling
4. Empty array handling
5. Large task list (10 tasks)

## Usage Examples

### Basic Usage
```ruby
# Create an epic with tasks
outcome = Epics::CreateFromManualSpec.run(
  user: current_user,
  repository: repo,
  tasks_json: [
    "Task 1: Setup database",
    "Task 2: Add API endpoints",
    "Task 3: Write tests"
  ].to_json,
  base_branch: 'main'
)

if outcome.valid?
  epic = outcome.result[:epic]
  tasks = outcome.result[:tasks]
  
  puts "Created Epic ##{epic.id}: #{epic.title}"
  tasks.each do |task|
    puts "  [#{task.position}] #{task.description}"
  end
else
  puts "Error: #{outcome.errors.full_messages.join(', ')}"
end
```

### With Cursor Agent Credential
```ruby
cursor_cred = Credential.find_by(user: current_user, service_name: 'cursor_agent')

outcome = Epics::CreateFromManualSpec.run(
  user: current_user,
  repository: repo,
  tasks_json: tasks_array.to_json,
  base_branch: 'develop',
  cursor_agent_credential_id: cursor_cred.id
)
```

### From Console
```ruby
# In Rails console
tasks = [
  "Implement user authentication",
  "Add profile management",
  "Create notification system"
]

result = Epics::CreateFromManualSpec.run!(
  user: User.first,
  repository: Repository.first,
  tasks_json: tasks.to_json
)

epic = result[:epic]
epic.tasks.ordered.each do |task|
  puts "[#{task.position}] #{task.description}"
end
```

## Task Position Verification

The implementation ensures tasks are created with sequential positions starting from 0:

```ruby
# Position assignment in the interaction
parsed_tasks.each_with_index.map do |task_description, index|
  Task.create!(
    epic: epic,
    description: task_description,
    position: index  # 0, 1, 2, 3, ...
  )
end
```

Tasks are automatically ordered by position through the Epic model:
```ruby
class Epic < ApplicationRecord
  has_many :tasks, -> { order(position: :asc) }, dependent: :destroy
end
```

## Error Handling

The interaction provides detailed error messages:

```ruby
# Invalid JSON
outcome = Epics::CreateFromManualSpec.run(
  user: user,
  repository: repo,
  tasks_json: 'not valid json'
)
# => outcome.errors[:tasks_json] = ["must be valid JSON: unexpected token at 'not valid json'"]

# Empty array
outcome = Epics::CreateFromManualSpec.run(
  user: user,
  repository: repo,
  tasks_json: '[]'
)
# => outcome.errors[:tasks_json] = ["must contain at least one task"]

# Non-string task
outcome = Epics::CreateFromManualSpec.run(
  user: user,
  repository: repo,
  tasks_json: '["Task 1", 123, "Task 3"]'
)
# => outcome.errors[:tasks_json] = ["task at index 1 must be a string"]
```

## Integration with Orchestra.ai Spec

This interaction follows the specification in `docs/spec-orchestrator.md`:

> **Epics::CreateFromManualSpec**
> * Inputs: user, repository, tasks_json (stringified array), base_branch, cursor_agent_credential_id
> * Logic:
>   1. Creates Epic with status pending.
>   2. Parses tasks_json (JSON.parse).
>   3. Iterates array, creating a Task for each string (setting description and position).
> * Returns: The new Epic and its Tasks.

✓ All requirements met

## Running Tests

To run the full test suite:
```bash
bundle exec rspec spec/interactions/epics/create_from_manual_spec_spec.rb
```

To run specific tests:
```bash
# Test task positions
bundle exec rspec spec/interactions/epics/create_from_manual_spec_spec.rb:42

# Test validations
bundle exec rspec spec/interactions/epics/create_from_manual_spec_spec.rb:115
```

## Next Steps

This interaction is ready for integration with:
1. **Controllers** - For API endpoints or web forms
2. **Console Commands** - For manual epic creation
3. **Background Jobs** - If needed for async processing
4. **Epics::Start** - To begin executing the created epic

Example controller usage:
```ruby
class EpicsController < ApplicationController
  def create_from_manual_spec
    outcome = Epics::CreateFromManualSpec.run(
      user: current_user,
      repository: Repository.find(params[:repository_id]),
      tasks_json: params[:tasks].to_json,
      base_branch: params[:base_branch] || 'main',
      cursor_agent_credential_id: params[:cursor_agent_credential_id]
    )
    
    if outcome.valid?
      redirect_to epic_path(outcome.result[:epic])
    else
      render json: { errors: outcome.errors.full_messages }, status: :unprocessable_entity
    end
  end
end
```

## Summary

✅ Created working `Epics::CreateFromManualSpec` interaction class  
✅ Implemented proper task position assignment (0, 1, 2, ...)  
✅ Added comprehensive validations for inputs  
✅ Created extensive test suite with 19 test cases  
✅ Verified task ordering through database queries  
✅ Added transaction support for atomicity  
✅ Created manual test script for verification  
✅ Documented usage and integration examples  

Task 4.1 is complete and ready for use.
