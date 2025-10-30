# Implementation Plan: AI Agent Orchestrator

## Common criteria
- write RSpec tests for each service and model
- write RSpec feature smoke tests for each page (the page loads, has expected text, shows data, etc.)
- if you must deviate from the specification, update the spec-orchestrator.md document (include justification for the deviation)


## Phase 3: Console-First Integration Testing

**Goal:** Manually verify all external integrations work from Rails console before building automation.

### Task 3.1: GitHub Service Console Validation
- **Deliverable:** Document/script showing console commands
- **Test from console:**
  ```ruby
  cred = Credential.create!(user: user, service_name: 'github', api_key: ENV['GITHUB_TOKEN'])
  gh = Services::GithubService.new(cred)

  # Test methods
  gh.infer_base_branch('landovsky/orchestra-ai')
  # Later: gh.merge_pull_request(task) with real PR
  # Later: gh.delete_branch(task)
  ```
- **AC:** Can successfully call GitHub API from console with real credentials

### Task 3.2: Cursor Service Console Validation
- **Deliverable:** Console script showing agent launch
- **Test from console:**
  ```ruby
  cred = Credential.create!(service_name: 'cursor_agent', api_key: ENV['CURSOR_KEY'])
  cursor = Services::CursorAgentService.new(cred)

  # Create minimal test task
  task = Task.create!(description: "Add comment to README", epic: epic, status: 'pending')

  # Launch agent manually
  result = cursor.launch_agent(
    task: task,
    webhook_url: "https://your-ngrok-url/webhooks/cursor/#{task.id}",
    branch_name: "test-manual-#{Time.now.to_i}"
  )
  ```
- **AC:** Can launch Cursor agent and get back agent ID

### Task 3.3: LLM Service Console Validation
- **Deliverable:** Console script showing spec generation
- **Test from console:**
  ```ruby
  cred = Credential.create!(service_name: 'openai', api_key: ENV['OPENAI_KEY'])
  llm = Services::LlmService.new(cred)

  spec = llm.generate_spec(
    "Add user authentication with email/password",
    "main"
  )
  # => { "tasks": ["Create User model", "Add Devise", ...] }
  ```
- **AC:** Can generate task list from prompt

---

## Phase 4: Manual Epic Creation & Basic Interactions

**Goal:** Create Epics and Tasks manually, test execution flow from console.

### Task 4.1: Epics::CreateFromManualSpec Interaction
- **Deliverable:** Working interaction class
- **Test from console:**
  ```ruby
  tasks = ["Task 1: Do X", "Task 2: Do Y", "Task 3: Do Z"]
  result = Epics::CreateFromManualSpec.run!(
    user: user,
    repository: repo,
    tasks_json: tasks.to_json,
    base_branch: "main",
    cursor_agent_credential: cursor_cred
  )
  epic = result.epic
  epic.tasks.count # => 3
  epic.tasks.first.position # => 1
  ```
- **AC:** Can create Epic with tasks from console

### Task 4.2: Tasks::UpdateStatus Interaction
- **Deliverable:** Status update with logging and broadcasting
- **Test from console:**
  ```ruby
  task = epic.tasks.first
  Tasks::UpdateStatus.run!(
    task: task,
    new_status: 'running',
    log_message: "Starting Cursor agent..."
  )
  task.reload.debug_log # Shows appended message
  ```
- **AC:** Task status updates and logs append

### Task 4.3: Epics::Start Interaction
- **Deliverable:** Start epic manually from console
- **Test from console:**
  ```ruby
  Epics::Start.run!(user: user, epic: epic)
  epic.reload.status # => 'running'
  epic.tasks.first.status # => 'pending' or 'running' if job ran
  ```
- **AC:** Epic status changes, first task job enqueued

---

## Phase 5: Task Execution Engine (Console Testable)

**Goal:** Run tasks end-to-end from console, observe Cursor agent behavior.

### Task 5.1: Tasks::ExecuteJob (Basic)
- **Deliverable:** Job that launches Cursor agent
- **Test from console:**
  ```ruby
  task = epic.tasks.first
  Tasks::ExecuteJob.new.perform(task.id)

  task.reload
  task.status # => 'running'
  task.cursor_agent_id # => "bc_abc123"
  task.branch_name # => "cursor-agent/task-1-a3f2"
  ```
- **AC:** Job launches agent, saves agent ID and branch

### Task 5.2: Webhook Controller (Minimal)
- **Deliverable:** Receive Cursor callbacks
- **Setup ngrok:** `ngrok http 3000`
- **Test manually:**
  1. Launch agent with ngrok webhook URL
  2. Watch webhook logs: `tail -f log/development.log`
  3. Verify webhook receives RUNNING, FINISHED, or ERROR
- **AC:** Controller receives and logs webhook payloads

### Task 5.3: Webhook FINISHED Handler
- **Deliverable:** Handle successful completion
- **Test from console:**
  ```ruby
  # Simulate webhook payload
  payload = {
    'status' => 'FINISHED',
    'target' => { 'prUrl' => 'https://github.com/user/repo/pull/123' }
  }

  # Or trigger real webhook and observe:
  task.reload
  task.status # => 'pr_open'
  task.pull_request_url # => "https://..."
  ```
- **AC:** Task transitions to pr_open, PR URL saved

---

## Phase 6: Simple UI (Hard-coded, Manual Refresh)

**Goal:** Create Epic in browser, start from UI, refresh to see updates.

### Task 6.1: EpicsController#new (Manual Spec Form)
- **Deliverable:** Simple form (no JS)
- **UI:** `/epics/new`
  - Select repository (dropdown)
  - Text input: base_branch (default: "main")
  - Textarea: tasks (one per line)
  - Submit button
- **AC:** Form renders and submits

### Task 6.2: EpicsController#create (Manual Spec)
- **Deliverable:** Create action calls interaction
- **Flow:** Submit → Epics::CreateFromManualSpec → Redirect to show
- **AC:** Epic created, redirects to `/epics/:id`

### Task 6.3: EpicsController#show (Basic, No Turbo)
- **Deliverable:** Static epic dashboard
- **Shows:**
  - Epic title, status
  - List of tasks with status badges
  - PR links (if present)
  - "Start Epic" button (if pending)
  - "Refresh" button (manual refresh)
- **AC:** Page displays epic and tasks, manual refresh shows updates

### Task 6.4: "Start Epic" Button
- **Deliverable:** POST /epics/:id/start
- **Flow:** Click → Epics::Start → Refresh page → See first task running
- **AC:** Can start epic from browser

---

## Phase 7: Sequential Task Orchestration

**Goal:** Complete end-to-end flow: launch → PR → merge → next task → complete.

### Task 7.1: Tasks::MergeJob (Basic Merge)
- **Deliverable:** Job that merges PR
- **Test from console:**
  ```ruby
  # After task has PR open
  Tasks::MergeJob.new.perform(task.id)

  task.reload.status # => 'completed'
  # Branch deleted from GitHub
  ```
- **AC:** PR merged, branch deleted, task marked completed

### Task 7.2: Tasks::MergeJob (Sequential Logic)
- **Deliverable:** Auto-start next task after merge
- **Flow:**
  1. Task 1 completes
  2. Merge job finds Task 2
  3. Task 2 ExecuteJob enqueued
  4. (Manual refresh shows Task 2 running)
- **AC:** Tasks execute sequentially without manual intervention

### Task 7.3: Tasks::MergeJob (Epic Completion)
- **Deliverable:** Mark epic complete when done
- **Flow:** Last task completes → Epic status = 'completed'
- **AC:** Epic marked complete, notification sent

### Task 7.4: Webhook ERROR Handler
- **Deliverable:** Handle agent failures
- **Flow:** Agent fails → Epic paused → Notification sent
- **AC:** Epic pauses on error, shows error in UI

---

## Phase 8: Real-time UI Updates (Turbo Streams)

**Goal:** Dashboard updates automatically without manual refresh.

### Task 8.1: Add Turbo Stream Subscription
- **Deliverable:** Enable ActionCable in show page
- **Change:** Add `<%= turbo_stream_from "epic_#{@epic.id}" %>`
- **AC:** Page subscribes to updates

### Task 8.2: Broadcasting from Tasks::UpdateStatus
- **Deliverable:** Broadcast status changes
- **Implementation:**
  ```ruby
  task.broadcast_replace_to(
    "epic_#{task.epic_id}",
    target: "task_#{task.id}",
    partial: "tasks/task",
    locals: { task: task }
  )
  ```
- **AC:** Task status updates appear automatically (no refresh needed)

### Task 8.3: Task Partial / ViewComponent
- **Deliverable:** Render task with proper DOM ID
- **Template:** Each task has `id="task_#{task.id}"`
- **Displays:** Name, status badge, PR link, debug log excerpt
- **AC:** Task updates replace smoothly in UI

### Task 8.4: Epic Status Broadcasting
- **Deliverable:** Broadcast epic-level changes
- **Shows:** Running → Completed/Paused transitions
- **AC:** Epic status updates automatically

---

## Phase 9: LLM-Generated Specs & Polish

**Goal:** Generate tasks from prompt, add notifications, polish UX.

### Task 9.1: Epics::GenerateSpecJob
- **Deliverable:** Background job calling LLM
- **Flow:** Create epic → Job generates tasks → Epic becomes pending
- **AC:** Can create epic from prompt

### Task 9.2: "Generate from Prompt" UI
- **Deliverable:** Alternate form on /epics/new
- **Uses:** Tabs or radio buttons to switch modes
- **AC:** Can submit prompt, see spec generated

### Task 9.3: Notifications::Send Interaction
- **Deliverable:** Multi-channel notifications
- **Supports:** Telegram, Email
- **AC:** User receives notifications on completion/errors

### Task 9.4: Credentials & Repositories UI
- **Deliverable:** Management pages for setup
- **Pages:** `/credentials`, `/repositories`
- **AC:** User can manage API keys and repos

---

## Testing Philosophy by Phase

| Phase | Testing Approach |
|-------|-----------------|
| 3 | Console scripts, real APIs with test accounts |
| 4-5 | Console + RSpec (interactions, jobs) |
| 6-7 | Feature specs with manual verification |
| 8-9 | Feature specs with system tests (ActionCable) |

## Key Incremental Checkpoints

After each phase, you should be able to:

- **Phase 3:** Run all services from console with real credentials
- **Phase 4:** Create and start epics from console
- **Phase 5:** Watch a full task execute: launch → webhook → PR
- **Phase 6:** Do the same from a browser (with refresh button)
- **Phase 7:** Watch multiple tasks execute sequentially
- **Phase 8:** Dashboard updates automatically
- **Phase 9:** Everything works end-to-end with LLM generation

This structure lets you validate each piece independently before adding complexity. Each phase delivers working functionality you can demo.