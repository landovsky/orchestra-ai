require 'rails_helper'

RSpec.describe EpicsController, type: :request do
  let(:user) { create(:user) }
  let(:repository) { create(:repository, user: user) }

  before do
    sign_in user
  end

  describe 'GET /epics/new' do
    it 'renders the new epic form' do
      get new_epic_path
      
      expect(response).to have_http_status(:ok)
    end
  end

  describe 'POST /epics' do
    let(:tasks_text) { "Task 1: Add user authentication\nTask 2: Create dashboard\nTask 3: Deploy to production" }
    let(:valid_params) do
      {
        epic: {
          repository_id: repository.id,
          base_branch: 'main',
          tasks: tasks_text
        }
      }
    end

    context 'with valid parameters' do
      it 'creates a new epic' do
        expect {
          post epics_path, params: valid_params
        }.to change(Epic, :count).by(1)
      end

      it 'creates tasks for the epic' do
        expect {
          post epics_path, params: valid_params
        }.to change(Task, :count).by(3)
      end

      it 'sets the epic attributes correctly' do
        post epics_path, params: valid_params
        
        epic = Epic.last
        expect(epic.user).to eq(user)
        expect(epic.repository).to eq(repository)
        expect(epic.base_branch).to eq('main')
        expect(epic.status).to eq('pending')
      end

      it 'creates tasks with correct positions' do
        post epics_path, params: valid_params
        
        epic = Epic.last
        expect(epic.tasks.count).to eq(3)
        expect(epic.tasks.map(&:position)).to eq([0, 1, 2])
      end

      it 'creates tasks with correct descriptions' do
        post epics_path, params: valid_params
        
        epic = Epic.last
        descriptions = epic.tasks.ordered.map(&:description)
        expect(descriptions).to eq([
          'Task 1: Add user authentication',
          'Task 2: Create dashboard',
          'Task 3: Deploy to production'
        ])
      end

      it 'redirects to the epic show page' do
        post epics_path, params: valid_params
        
        epic = Epic.last
        expect(response).to redirect_to(epic_path(epic))
      end

      it 'sets a success notice' do
        post epics_path, params: valid_params
        
        follow_redirect!
        expect(response.body).to include('Epic created successfully')
      end
    end

    context 'with empty tasks' do
      let(:invalid_params) do
        {
          epic: {
            repository_id: repository.id,
            base_branch: 'main',
            tasks: ''
          }
        }
      end

      it 'does not create an epic' do
        expect {
          post epics_path, params: invalid_params
        }.not_to change(Epic, :count)
      end

      it 'renders the new template' do
        post epics_path, params: invalid_params
        
        expect(response).to have_http_status(:unprocessable_entity)
      end

      it 'displays an error message' do
        post epics_path, params: invalid_params
        
        expect(response.body).to include('must contain at least one task')
      end
    end

    context 'with blank lines in tasks' do
      let(:tasks_with_blanks) { "Task 1: First task\n\n\nTask 2: Second task\n" }
      let(:params_with_blanks) do
        {
          epic: {
            repository_id: repository.id,
            base_branch: 'main',
            tasks: tasks_with_blanks
          }
        }
      end

      it 'creates only non-blank tasks' do
        expect {
          post epics_path, params: params_with_blanks
        }.to change(Task, :count).by(2)
      end
    end

    context 'with custom base_branch' do
      let(:custom_branch_params) do
        {
          epic: {
            repository_id: repository.id,
            base_branch: 'develop',
            tasks: tasks_text
          }
        }
      end

      it 'uses the custom base branch' do
        post epics_path, params: custom_branch_params
        
        epic = Epic.last
        expect(epic.base_branch).to eq('develop')
      end
    end

    context 'with missing repository_id' do
      let(:invalid_params) do
        {
          epic: {
            base_branch: 'main',
            tasks: tasks_text
          }
        }
      end

      it 'raises an error' do
        expect {
          post epics_path, params: invalid_params
        }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end
  end

  describe 'GET /epics/:id' do
    let(:epic) { create(:epic, user: user, repository: repository) }
    let!(:task1) { create(:task, epic: epic, position: 0, description: 'First task') }
    let!(:task2) { create(:task, epic: epic, position: 1, description: 'Second task') }

    it 'renders the show page' do
      get epic_path(epic)
      
      expect(response).to have_http_status(:ok)
    end

    it 'displays the epic title' do
      get epic_path(epic)
      
      expect(response.body).to include(epic.title)
    end

    it 'displays all tasks' do
      get epic_path(epic)
      
      expect(response.body).to include('First task')
      expect(response.body).to include('Second task')
    end
  end
end
