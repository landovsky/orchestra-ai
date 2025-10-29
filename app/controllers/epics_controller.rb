class EpicsController < ApplicationController
  before_action :authenticate_user!

  def new
    @epic = Epic.new
    @repositories = current_user.repositories
  end
end
