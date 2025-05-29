class TodosController < ApplicationController
  def index
    @todos = Todo.all
  end

  def new
    @todo = Todo.new
  end

  def create
    @todo = Todo.new(todo_params)
    if @todo.save
      redirect_to todos_path, notice: 'Todoを作成しました'
    else
      render :new
    end
  end

  def edit
    @todo = Todo.find(params[:id])
  end

  def update
    @todo = Todo.find(params[:id])
    if @todo.update(todo_params)
      redirect_to todos_path, notice: 'Todoを更新しました'
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @todo = Todo.find(params[:id])
    @todo.destroy
    redirect_to todos_path, notice: 'Todoを削除しました'
  end

  private 

  def todo_params
    params.require(:todo).permit(:title, :done)
  end
end
