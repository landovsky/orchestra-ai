class Epics::NewPageComponent < BaseComponent
  def initialize(epic:, repositories:)
    @epic = epic
    @repositories = repositories
  end
end
