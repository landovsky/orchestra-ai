class EpicsController < ApplicationController
  before_action :authenticate_user!

  def new
    @epic = Epic.new
    @repositories = current_user.repositories
  end

  def show
    @epic = current_user.epics.includes(tasks: []).find(params[:id])
  end
end
