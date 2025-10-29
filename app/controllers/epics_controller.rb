class EpicsController < ApplicationController
  before_action :authenticate_user!

  def new
    @epic = Epic.new
    @repositories = current_user.repositories
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
      render :new, status: :unprocessable_entity
    end
  end

  def show
    @epic = Epic.find(params[:id])
  end

  def start
    @epic = Epic.find(params[:id])
    
    outcome = Epics::Start.run(
      user: current_user,
      epic: @epic
    )

    if outcome.valid?
      redirect_to epic_path(@epic), notice: "Epic started successfully! First task is being executed."
    else
      redirect_to epic_path(@epic), alert: "Failed to start epic: #{outcome.errors.full_messages.join(', ')}"
    end
  end
end
