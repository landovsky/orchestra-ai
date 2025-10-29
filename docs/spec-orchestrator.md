# **Orchestra.ai - AI Agent Orchestrator**

## **1\. Core Data Models (Schema)**

* **User** (via Devise)
  * email, name, google\_oauth\_token, google\_refresh\_token
  * has\_many :credentials
  * has\_many :notification\_channels
  * has\_many :repositories
  * has\_many :epics
* **Credential** (Encrypted)
  * name (e.g., "Personal GitHub", "OpenAI Key", "Cursor API Key")
  * service\_name (e.g., github, openai, cursor\_agent, claude, gemini)
  * api\_key (encrypted, using ActiveRecord::Encryption)
  * belongs\_to :user
* **Repository**
  * name (e.g., "my-app")
  * github\_url (e.g., https://github.com/my-user/my-app)
  * belongs\_to :user
  * belongs\_to :github\_credential, class\_name: 'Credential'
  * has\_many :epics
* **Epic** (The main orchestration job)
  * title
  * prompt (the high-level user request)
  * base\_branch (e.g., "main" or "epic/my-feature")
  * status (e.g., pending, generating\_spec, running, paused, completed, failed)
  * belongs\_to :repository
  * belongs\_to :user (the user who initiated it)
  * belongs\_to :llm\_credential, class\_name: 'Credential'
  * belongs\_to :cursor\_agent\_credential, class\_name: 'Credential'
  * has\_many :tasks, \-\> { order(position: :asc) }
* **Task** (A single step in the epic)
  * name
  * description (the prompt for the agent, e.g., "Add a new endpoint for /api/users")
  * status (e.g., pending, running, pr\_open, merging, completed, failed)
  * branch\_name (e.g., cursor-agent/task-1-abc123)
  * pull\_request\_url
  * cursor\_agent\_id (string, the ID from the Cursor API, e.g., "bc\_abc123")
  * debug\_log (text, for storing agent output/errors)
  * position (integer, for sequential ordering)
  * belongs\_to :epic
* **NotificationChannel**
  * service\_name (e.g., telegram, email)
  * channel\_id (e.g., Telegram chat ID)
  * belongs\_to :user

## **2\. Core Workflows (ActiveInteractions)**

This is where all business logic lives. Controllers and Jobs *only* call these interactions.

* **Credentials::Create**
  * Inputs: user, name, service\_name, api\_key
  * Logic: Encrypts and saves the Credential.
* **Epics::CreateFromPrompt**
  * Inputs: user, repository, prompt, base\_branch (optional), llm\_credential\_id, cursor\_agent\_credential\_id
  * Logic:
    1. Creates an Epic with status generating\_spec.
    2. Enqueues Epics::GenerateSpecJob.perform\_async(epic.id, base\_branch).
  * Returns: The new Epic.
* **Epics::CreateFromManualSpec**
  * Inputs: user, repository, tasks\_json (stringified array), base\_branch, cursor\_agent\_credential\_id
  * Logic:
    1. Creates Epic with status pending.
    2. Parses tasks\_json (JSON.parse).
    3. Iterates array, creating a Task for each string (setting description and position).
  * Returns: The new Epic and its Tasks.
* **Epics::Start**
  * Inputs: user, epic
  * Logic:
    1. Validates epic is pending.
    2. Sets epic.status to running.
    3. Finds the first pending Task.
    4. Enqueues Tasks::ExecuteJob.perform\_async(task.id).
    5. Broadcasts update via Turbo Streams.
* **Tasks::UpdateStatus**
  * Inputs: task, new\_status, log\_message (optional), pr\_url (optional)
  * Logic:
    1. Updates task.status to new\_status.
    2. Updates task.pull\_request\_url if provided.
    3. Appends log\_message to task.debug\_log.
    4. Broadcasts a Turbo Stream update (e.g., broadcast\_replace\_to "epic\_\#{task.epic\_id}", target: "task\_\#{task.id}", ...).
* **Notifications::Send**
  * Inputs: user, message
  * Logic:
    1. Finds user.notification\_channels.
    2. For each channel, enqueues a specific job (e.g., Telegram::SendMessageJob.perform\_async(channel.id, message)).

## **3\. Background Jobs (Sidekiq)**

* **Epics::GenerateSpecJob**
  * Input: epic\_id, base\_branch (optional)
  * Logic:
    1. Get epic and llm\_credential.
    2. If base\_branch is nil, call GithubService to infer it.
    3. Call LlmService.new(epic.llm\_credential).generate\_spec(epic.prompt, epic.base\_branch).
    4. The LLM should return JSON: { "tasks": \["Implement user auth", "Add /profile endpoint", ...\] }.
    5. Parse response, create Task records.
    6. Update epic.status to pending.
    7. Call Notifications::Send.run\!(user: epic.user, message: "Spec for '\#{epic.title}' is ready\!").
* **Tasks::ExecuteJob**
  * Input: task\_id
  * Logic:
    1. Get task and its epic and credentials.
    2. Call Tasks::UpdateStatus.run\!(task: task, new\_status: 'running', log: "Launching Cursor agent...").
    3. Generate branch\_name \= "cursor-agent/task-\#{task.id}-\#{SecureRandom.hex(4)}".
    4. Generate webhook\_url \= "https://your-app.com/webhooks/cursor/\#{task.id}" (using Rails.application.routes.url\_helpers).
    5. Call CursorAgentService.new(task.epic.cursor\_agent\_credential).launch\_agent(task: task, webhook\_url: webhook\_url, branch\_name: branch\_name).
    6. This service returns the agent's ID.
    7. Update task.update\!(cursor\_agent\_id: agent\_id, branch\_name: branch\_name).
    8. This job is now complete. The Webhooks::CursorController will take over.
* **Tasks::MergeJob**
  * Input: task\_id
  * Logic:
    1. Get task and github\_credential.
    2. Call Tasks::UpdateStatus.run\!(task: task, new\_status: 'merging', log: "Agent finished. Attempting to merge PR...").
    3. Call GithubService.new(cred).merge\_pull\_request(task).
    4. If successful:
    * Call Tasks::UpdateStatus.run\!(task: task, new\_status: 'completed', log: "Merge successful.").
    * Call GithubService.new(cred).delete\_branch(task).
    * Call Notifications::Send.run\!(user: task.epic.user, message: "Task '\#{task.name}' complete\!").
    * Find next\_task \= task.epic.tasks.find\_by(status: 'pending').
    * If next\_task:
      * Enqueue Tasks::ExecuteJob.perform\_async(next\_task.id).
    * Else:
      * Update task.epic.status to completed.
      * Call Notifications::Send.run\!(user: task.epic.user, message: "Epic '\#{task.epic.title}' is complete\!").
    5. If merge failed (e.g., conflict):
    * Call Tasks::UpdateStatus.run\!(task: task, new\_status: 'failed', log: "Merge conflict detected\! Manual intervention required.").
    * Update task.epic.status to paused.
    * Call Notifications::Send.run\!(user: task.epic.user, message: "EPIC PAUSED: Merge conflict on '\#{task.name}'").

## **4\. Key Services (lib/)**

* **GithubService**
  * Wrapper around the octokit gem.
  * Methods: infer\_base\_branch, merge\_pull\_request(task) (finds PR by branch\_name and merges it), delete\_branch(task).
* **LlmService**
  * Adapter pattern.
  * initialize(credential): Loads correct client.
  * generate\_spec(prompt, base\_branch): Calls LLM to return JSON ({ "tasks": \[...\] }).
* **CursorAgentService**
  * initialize(credential): Stores @api\_key \= credential.api\_key.
  * launch\_agent(task:, webhook\_url:, branch\_name:)
    1. Builds payload:
       {
         "prompt": { "text": task.description },
         "source": {
           "repository": task.epic.repository.github\_url,
           "ref": task.epic.base\_branch
         },
         "target": {
           "branchName": branch\_name,
           "autoCreatePr": true
         },
         "webhook": {
           "url": webhook\_url,
           "secret": "your-webhook-secret"
         }
       }

    2. POSTs to https://api.cursor.com/v0/agents with Authorization: Bearer \#{@api\_key}.
    3. Returns parsed JSON response (e.g., { "id": "bc\_abc123", ... }).

## **5\. Webhook Controller**

* **Webhooks::CursorController**
  * Receives POST requests to /webhooks/cursor/:id (where :id is the task.id).
  * create action:
    1. Verify webhook secret.
    2. task \= Task.find(params\[:id\]).
    3. payload \= JSON.parse(request.body).
    4. case payload.status:
    * when 'FINISHED':
      * pr\_url \= payload.target.prUrl
      * Call Tasks::UpdateStatus.run\!(task: task, new\_status: 'pr\_open', log: "Agent finished, PR created.", pr\_url: pr\_url).
      * Enqueue Tasks::MergeJob.perform\_async(task.id).
    * when 'ERROR':
      * Call Tasks::UpdateStatus.run\!(task: task, new\_status: 'failed', log: "Agent failed: \#{payload.error || 'Unknown error'}").
      * Update task.epic.status to paused.
      * Call Notifications::Send.run\!(user: task.epic.user, message: "EPIC PAUSED: Task '\#{task.name}' failed.").
    * when 'RUNNING':
      * Call Tasks::UpdateStatus.run\!(task: task, log: "Agent is running...").
    5. render json: { status: 'received' }, status: :ok.

## **6\. UI (Views, ViewComponents, Stimulus)**

* **EpicsController\#show (The Dashboard)**
  * Renders the Epic details and a list of its Tasks.
  * Includes \<%= turbo\_stream\_from "epic\_\#{epic.id}" %\>.
  * Each task has a DOM ID: id="task\_\<%= task.id %\>".
  * The Tasks::UpdateStatus interaction will broadcast updates that target these DOM IDs, replacing the task's partial to show the new status (e.g., showing a link to the pr\_url).