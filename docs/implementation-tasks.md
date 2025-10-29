# Implementation Tasks: AI Agent Orchestrator

This document breaks down the implementation of the AI Agent Orchestrator (based on spec-orchestrator.md) into incremental tasks, grouped by concern.

## Common criteria
- write RSpec tests for each service, model
- write RSpec feature smoke tests for each page (the page loads, has expected text, shows data, etc.)

## Milestone 1: Core Setup & Data Models

Goal: Establish the application, database, and all core models. No UI or logic yet.

- [ ] Task 1.2: User Model & Devise Setup
  * Description: Install Devise and create the User model.
  * AC: db:migrate runs. User model exists. Basic Devise routes are active.
- [ ] Task 1.3: Credential Model
  * Description: Create the Credential model migration and class. Configure ActiveRecord::Encryption for the api\_key field.
  * AC: Migration for credentials table (with user:references, service\_name, name, api\_key) runs. Credential.new(api\_key: "test").api\_key returns "test", but the value in the DB is encrypted.
- [ ] Task 1.4: Repository Model
  * Description: Create the Repository model and migration, including the foreign key for github\_credential.
  * AC: Migration for repositories table (with user:references, name, github\_url, github\_credential\_id:references) runs. Model associations (belongs\_to :user, belongs\_to :github\_credential) are defined.
- [ ] Task 1.5: Epic Model
  * Description: Create the Epic model and migration. Add enums for status.
  * AC: Migration for epics table (with user:references, repository:references, status, base\_branch, etc.) runs. Epic.new.status defaults to pending.
- [ ] Task 1.6: Task Model
  * Description: Create the Task model and migration. Add enums for status and position for ordering.
  * AC: Migration for tasks table (with epic:references, status, position, cursor\_agent\_id, pr\_url, debug\_log:text) runs. belongs\_to :epic association exists.
- [ ] Task 1.7: NotificationChannel Model
  * Description: Create the NotificationChannel model and migration.
  * AC: Migration for notification\_channels (with user:references, service\_name, channel\_id) runs.
- [ ] Task 1.8: AVO Admin Setup (Optional but recommended)
  * Description: Install AVO and create basic resources for all new models.
  * AC: Admin can log in at /avo. Can view and manually create/edit Users, Repositories, and Credentials.

## Milestone 2: Core Service Wrappers (The lib)

Goal: Create the pure-Ruby client classes that wrap external APIs. These should be testable with stubs, no Rails dependencies.

- [ ] Task 2.1: GithubService Wrapper
  * Description: Create lib/services/github\_service.rb. Implement initialize(credential) that sets up an Octokit::Client.
  * AC: GithubService.new(credential) successfully initializes the client.
- [ ] Task 2.2: GithubService\#merge\_pull\_request(task)
  * Description: Implement the method to find a PR by task.branch\_name (on task.epic.repository.name) and merge it.
  * AC: Method correctly calls octokit.merge\_pull\_request and returns the merge SHA. Handles "not found" or "not mergeable" errors.
- [ ] Task 2.3: GithubService\#delete\_branch(task)
  * Description: Implement the method to delete the remote Git branch after a successful merge.
  * AC: Method correctly calls octokit.delete\_branch.
- [ ] Task 2.4: GithubService\#infer\_base\_branch
  * Description: Implement a method to infer the base branch (e.g., 'main' or 'master') for a given repository. This can be done by fetching the repository's default branch.
  * AC: GithubService.new(cred).infer\_base\_branch(repo\_name) returns a string (e.g., 'main').
- [ ] Task 2.5: CursorAgentService Wrapper
  * Description: Create lib/services/cursor\_agent\_service.rb. Implement initialize(credential) and launch\_agent(task:, webhook\_url:, branch\_name:).
  * AC: Method builds the correct JSON payload (as per spec-orchestrator.md) and POSTs to the Cursor API, returning the parsed response body (e.g., { "id": "..." }).
- [ ] Task 2.6: LlmService Adapter
  * Description: Create lib/services/llm\_service.rb. Implement initialize(credential) and generate\_spec(prompt, base\_branch).
  * AC: The initialize method selects the correct client (e.g., OpenAI, Anthropic) based on credential.service\_name. generate\_spec returns a { "tasks": \[...\] } hash. (Can be a hard-coded stub for now).
- [ ] Task 2.7: Telegram::SendMessageJob
  * Description: Create a basic Sidekiq job to send a message via the Telegram Bot API.
  * AC: Telegram::SendMessageJob.perform\_async(chat\_id, "hello") successfully sends "hello" to the specified chat.

## Milestone 3: Authentication & Core UI (User Setup)

Goal: Allow a user to sign in and configure their account.

- [ ] Task 3.1: Google OAuth2 Login
  * Description: Configure Devise with omniauth-google-oauth2.
  * AC: A "Sign in with Google" button exists. User can click it, authenticate, and a User record is created/found.
- [ ] Task 3.2: Credentials Management (Interactions)
  * Description: Create ActiveInteraction classes for Credentials::Create, Credentials::Update, and Credentials::Destroy.
  * AC: Interactions successfully create, update, and destroy Credential records, validating user ownership.
- [ ] Task 3.3: Credentials Management (UI)
  * Description: Create a CredentialsController and corresponding views (using ViewComponents) at /credentials.
  * AC: User can navigate to /credentials. User can see a list of their credentials. User can add a new credential (e.g., "Cursor API Key"). User can delete a credential.
- [ ] Task 3.4: Repositories Management (Interactions & UI)
  * Description: Create Repositories::Create interaction and a simple RepositoriesController with views.
  * AC: User can navigate to /repositories. User can add a new Repository, selecting their github\_credential from a dropdown.

## Milestone 4: Epic Creation (The "Happy Path" Setup)

Goal: Allow the user to define and save an Epic and its Tasks.

- [ ] Task 4.1: Epics::CreateFromManualSpec Interaction
  * Description: Build the interaction to create an Epic and its child Task records from a JSON array of strings.
  * AC: Epics::CreateFromManualSpec.run\!(...) successfully creates one Epic and multiple Task records with correct position values.
- [ ] Task 4.2: "New Epic" Form UI
  * Description: Create EpicsController\#new and a corresponding view. The form should include a select for Repository, a text input for base\_branch, and a textarea for tasks (one per line).
  * AC: The /epics/new page renders.
- [ ] Task 4.3: "New Epic" Form (Stimulus)
  * Description: Add a Stimulus controller to the "New Epic" form.
  * AC: The controller intercepts the form submit event. It reads the textarea (splitting by newline), converts it to a JSON string, and injects it into a hidden tasks\_json field before the form is submitted.
- [ ] Task 4.4: EpicsController\#create (Manual Spec)
  * Description: Wire the EpicsController\#create action to call the Epics::CreateFromManualSpec interaction with the form parameters.
  * AC: Submitting the "New Epic" form successfully creates the records and redirects to the Epics\#show page.
- [ ] Task 4.5: Epics::GenerateSpecJob (Sidekiq)
  * Description: Implement the job that calls LlmService and saves the resulting Tasks.
  * AC: Epics::GenerateSpecJob.perform\_async(epic.id) runs, calls the service, and populates the Epic with Task records. It updates the epic.status to pending and sends a notification.
- [ ] Task 4.6: "New Epic" UI (LLM Spec)
  * Description: Add a "Generate from Prompt" path to the Epics\#new form (e.g., using tabs).
  * AC: User can enter a high-level prompt. Submitting this form calls an action that creates an Epic (status: generating\_spec) and enqueues Epics::GenerateSpecJob.

## Milestone 5: The Orchestration Engine (Async Jobs)

Goal: Implement the core async jobs that run the orchestration.

- [ ] Task 5.1: Tasks::UpdateStatus Interaction
  * Description: Create the interaction to update a task's status and append to its log. This interaction will be called by jobs and controllers.
  * AC: Tasks::UpdateStatus.run\!(task: task, new\_status: 'running', log: '...') updates the task and saves it.
- [ ] Task 5.2: Tasks::ExecuteJob (Sidekiq)
  * Description: Implements the job that launches the Cursor agent.
  * AC: Job calls Tasks::UpdateStatus (to running). It calls CursorAgentService\#launch\_agent with the correct, unique webhook URL. It saves the returned cursor\_agent\_id to the task.
- [ ] Task 5.3: Tasks::MergeJob (Sidekiq)
  * Description: Implements the job that merges the agent's PR.
  * AC: Job calls Tasks::UpdateStatus (to merging). It calls GithubService\#merge\_pull\_request. On success, it calls GithubService\#delete\_branch.
- [ ] Task 5.4: Tasks::MergeJob (Sequential Logic)
  * Description: Extend Tasks::MergeJob to handle the sequence.
  * AC: After a successful merge, the job calls Tasks::UpdateStatus (to completed). It then finds the *next- [ ] Task in the Epic (by position). If one exists, it enqueues Tasks::ExecuteJob.perform\_async(next\_task.id).
- [ ] Task 5.5: Tasks::MergeJob (Completion Logic)
  * Description: Extend Tasks::MergeJob to handle the end of the epic.
  * AC: If no next\_task is found, the job updates the parent epic.status to completed and sends a "Epic Complete" notification.
- [ ] Task 5.6: Epics::Start Interaction & Route
  * Description: Create the Epics::Start interaction that kicks off the whole process. Add a POST /epics/:id/start route.
  * AC: Epics::Start.run\!(epic: epic) sets epic.status to running and enqueues Tasks::ExecuteJob for the *first- [ ] task.

## Milestone 6: Real-time Dashboard (UI)

Goal: Create the Epics\#show dashboard that updates in real-time.

- [ ] Task 6.1: Epics\#show View
  * Description: Build the EpicsController\#show view.
  * AC: Page renders the Epic's title. It includes the \<%= turbo\_stream\_from "epic\_\#{epic.id}" %\> tag. It renders a list of tasks, each using a \_task partial.
- [ ] Task 6.2: \_task Partial / ViewComponent
  * Description: Create the partial/component for rendering a single task.
  * AC: The partial has a root DOM ID of task\_\<%= task.id %\>. It displays the task.description, task.status (as a badge), and a link to task.pull\_request\_url if present.
- [ ] Task 6.3: Broadcasting from Tasks::UpdateStatus
  * Description: Modify the Tasks::UpdateStatus interaction to broadcast changes.
  * AC: After saving the task, the interaction calls task.broadcast\_replace\_to "epic\_\#{task.epic\_id}", partial: "tasks/task", .... The dashboard UI updates in real-time when a task's status changes.
- [ ] Task 6.4: "Start Epic" Button
  * Description: Add a "Start" button to the Epics\#show page (visible if epic.status \== 'pending').
  * AC: Button makes a POST request to the epics\#start route. On click, the page updates (via Turbo Stream broadcast) to show the first task as "running".

## Milestone 7: Webhooks & Error Handling

Goal: Close the loop by receiving events from Cursor.

- [ ] Task 7.1: Webhooks::CursorController
  * Description: Create the controller at /webhooks/cursor/:id (where :id is task.id).
  * AC: Route is public (skips CSRF). The create action can receive a POST request and find the Task from the URL.
- [ ] Task 7.2: Webhook FINISHED Logic
  * Description: Implement the logic for payload.status \== 'FINISHED'.
  * AC: Controller calls Tasks::UpdateStatus (to pr\_open, saving the prUrl). It enqueues Tasks::MergeJob.perform\_async(task.id).
- [ ] Task 7.3: Webhook ERROR Logic
  * Description: Implement the logic for payload.status \== 'ERROR'.
  * AC: Controller calls Tasks::UpdateStatus (to failed, saving the error message to debug\_log). It updates the parent epic.status to paused and sends a failure notification.