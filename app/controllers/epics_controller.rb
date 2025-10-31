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
      render Epics::NewPageComponent.new(epic: @epic, repositories: @repositories), status: :unprocessable_entity
    end
  end

  def show
    @epic = current_user.epics.includes(tasks: []).find(params[:id])
    render Epics::ShowPageComponent.new(epic: @epic)
  end
end
