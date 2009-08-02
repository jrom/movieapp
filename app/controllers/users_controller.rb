class UsersController < ApplicationController
  before_filter :find_user, :only => [:show, :edit, :update, :destroy]

  def new
    @user = User.new
  end

  def create
    @user = User.new(params[:user])

    if @user.save
      #flash[:notice] = "Registration successful."
      redirect_to @user
    else
      render :action => 'new'
    end
  end

  def show
  end

  def edit
    @user = current_user
  end

  def update
    @user = current_user
    if @user.update_attributes(params[:user])
      flash[:notice] = "Successfully updated profile."
      redirect_to @user
    else
      render :action => 'edit'
    end
  end

  protected

    def find_user
      @user = User.find(params[:id])
    end

end
