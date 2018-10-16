class UsersController < ApplicationController
  DEFAULT_PAGE = 'v'

  def index
    if !params[:page]
      return redirect_to users_path(page: DEFAULT_PAGE)
    end

    @dividing_user_pairs = Presenters::Users::Index.new(current_page_string: params[:page]).dividing_user_pairs
  end

  def show
    @user = User.find params[:id]
  end
end
