# Task 6.4: Start Epic Button - COMPLETED

## Overview
Implemented the "Start Epic" button functionality that allows users to start an epic from the browser UI. When clicked, the epic status changes to 'running' and the first task execution is automatically enqueued.

## Implementation Details

### 1. Created Epics::Start Interaction
**File:** `/workspace/app/interactions/epics/start.rb`

This interaction handles the business logic for starting an epic:
- Validates epic belongs to the user
- Validates epic is in 'pending' status (can only start pending epics)
- Validates epic has a cursor agent credential configured
- Validates epic has at least one task
- Updates epic status to 'running'
- Enqueues the first task (lowest position) for execution via `Tasks::ExecuteJob`
- Uses database transaction to ensure atomicity

**Key validations:**
- Epic ownership check
- Status check (must be pending)
- Cursor agent credential presence
- At least one task exists

### 2. Added POST Route
**File:** `/workspace/config/routes.rb`

Added a member route for starting an epic:
```ruby
resources :epics, only: [:new, :create, :show] do
  member do
    post :start
  end
end
```

This creates the route: `POST /epics/:id/start` with the helper `start_epic_path(@epic)`

### 3. Created Controller Action
**File:** `/workspace/app/controllers/epics_controller.rb`

Added the `start` action:
- Finds the epic by ID
- Calls the `Epics::Start` interaction with current user and epic
- Redirects to epic show page with appropriate success/error message
- Success: "Epic started successfully! First task is being executed."
- Failure: Shows validation errors from the interaction

### 4. Updated UI Button
**File:** `/workspace/app/views/epics/show.html.erb`

Updated the "Start Epic" button:
- Removed `disabled: true` attribute
- Changed from `"#"` to actual route `start_epic_path(@epic)`
- Button only displays when epic is in 'pending' status
- Uses POST method to trigger the start action

### 5. Created Comprehensive Spec
**File:** `/workspace/spec/interactions/epics/start_spec.rb`

Created extensive test coverage including:

**Valid scenarios:**
- Updates epic status to running
- Enqueues first task execution job
- Does not enqueue subsequent tasks
- Returns the epic object

**Invalid scenarios:**
- Epic doesn't belong to user
- Epic is already running
- Epic is completed
- Epic is paused
- Epic has no cursor agent credential
- Epic has no tasks
- Validation failures don't change status
- Validation failures don't enqueue jobs

**Edge cases:**
- Transaction rollback on job enqueue failure
- Multiple tasks - only first is enqueued
- Tasks with non-sequential positions - correct one selected

### 6. Created Test Script
**File:** `/workspace/script/test_start_epic.rb`

Created a console test script demonstrating the functionality:
- Creates test data (user, repository, credential)
- Creates an epic with multiple tasks
- Starts the epic
- Shows status updates

## User Flow

1. User creates an epic with tasks (Task 6.2)
2. User views epic on show page (Task 6.3)
3. Epic shows "Start Epic" button (only if status is 'pending')
4. User clicks "Start Epic" button
5. POST request sent to `/epics/:id/start`
6. `Epics::Start` interaction executes:
   - Validates user ownership and epic state
   - Changes epic status to 'running'
   - Enqueues first task via `Tasks::ExecuteJob`
7. User redirected back to epic show page
8. Success notice displayed
9. User can refresh page to see first task status updates

## Acceptance Criteria (from implementation-tasks.md)

✅ **Deliverable:** POST /epics/:id/start route created
✅ **Flow:** Click → Epics::Start → Refresh page → See first task running
✅ **AC:** Can start epic from browser

## Technical Notes

- Uses ActiveInteraction pattern for business logic
- Maintains transaction integrity with `ActiveRecord::Base.transaction`
- Proper error handling and user feedback
- Follows existing code patterns from Task 6.2 and 6.3
- Background job pattern for async task execution
- Uses `perform_later` for job enqueueing (non-blocking)

## Files Modified

1. `/workspace/app/interactions/epics/start.rb` (created)
2. `/workspace/config/routes.rb` (modified)
3. `/workspace/app/controllers/epics_controller.rb` (modified)
4. `/workspace/app/views/epics/show.html.erb` (modified)
5. `/workspace/spec/interactions/epics/start_spec.rb` (created)
6. `/workspace/script/test_start_epic.rb` (created)

## Dependencies

- Depends on `Tasks::ExecuteJob` (implemented in Task 5.1)
- Depends on `Epics::CreateFromManualSpec` (implemented in Task 4.1)
- Used by Phase 7 sequential task orchestration

## Testing

To test from console:
```ruby
# Load the script
load 'script/test_start_epic.rb'

# Or test manually:
user = User.first
epic = Epic.find(id)
outcome = Epics::Start.run(user: user, epic: epic)
outcome.valid? # => true
epic.reload.status # => "running"
```

## Next Steps

This completes Phase 6 (Simple UI). The next phase is:
- **Phase 7:** Sequential Task Orchestration
  - Task 7.1: Tasks::MergeJob (Basic Merge)
  - Task 7.2: Tasks::MergeJob (Sequential Logic)
  - Task 7.3: Tasks::MergeJob (Epic Completion)
  - Task 7.4: Webhook ERROR Handler

The Start Epic functionality is now fully operational and ready for the orchestration phase.
