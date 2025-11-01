class EpicsController < ApplicationController
  before_action :authenticate_user!

  def new
    @epic = Epic.new
    @repositories = current_user.repositories
    render Epics::NewPageComponent.new(epic: @epic, repositories: @repositories)
  end

  def create
    # Parse tasks from textarea (one per line)
    tasks_text = params[:epic][:tasks] || ""
    tasks_array = tasks_text.split("\n").map(&:strip).reject(&:empty?)

    # Call the interaction
    outcome = Epics::CreateFromManualSpec.run(
      user: current_user,
      repository: Repository.find(params[:epic][:repository_id]),
      tasks_json: tasks_array.to_json,
      base_branch: params[:epic][:base_branch] || "main"
    )

    if outcome.valid?
      redirect_to epic_path(outcome.result[:epic]), notice: "Epic created successfully!"
    else
      # Re-render the form with errors
      @epic = Epic.new
      @repositories = current_user.repositories
      flash.now[:alert] = outcome.errors.full_messages.join(", ")
      render Epics::NewPageComponent.new(
        epic: @epic,
        repositories: @repositories,
        tasks_input: tasks_text
      ), status: :unprocessable_entity
    end
  end

  def show
    @epic = current_user.epics.includes(tasks: []).find(params[:id])
    render Epics::ShowPageComponent.new(epic: @epic)
  end

  def index
    @epics = current_user.epics.includes(:repository, :tasks).order(created_at: :desc)
    render Epics::IndexPageComponent.new(epics: @epics)
  end

  def dispatch_agent
    @epic = current_user.epics.find(params[:id])

    # Find the first pending task
    task = @epic.tasks.pending.ordered.first

    if task.nil?
      redirect_to epic_path(@epic), alert: "No pending tasks available to dispatch."
      return
    end

    # Execute the task synchronously
    begin
      ::Tasks::Services::Execute.run!(task: task)
      redirect_to epic_path(@epic), notice: "Agent dispatched successfully for task ##{task.position}!"
    rescue StandardError => e
      redirect_to epic_path(@epic), alert: "Failed to dispatch agent: #{e.message}"
    end
  end
end
