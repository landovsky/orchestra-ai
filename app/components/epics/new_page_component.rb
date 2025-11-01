class Epics::NewPageComponent < BaseComponent
  def initialize(epic:, repositories:, tasks_input: nil)
    @epic = epic
    @repositories = repositories
    @tasks_input = tasks_input
  end

  private

  attr_reader :tasks_input
end
