require 'rails_helper'

RSpec.describe EpicsController, type: :controller do
  let(:user) { create(:user) }
  let(:github_credential) { create(:credential, user: user, service_name: 'github') }
  let(:repository) { create(:repository, user: user, github_credential: github_credential) }

  before do
    sign_in user
  end

  describe 'GET #new' do
    context 'when user is authenticated' do
      it 'returns http success' do
        get :new
        expect(response).to have_http_status(:success)
      end

      it 'assigns a new epic to @epic' do
        get :new
        expect(assigns(:epic)).to be_a_new(Epic)
      end

      it 'assigns current user repositories to @repositories' do
        repository # create the repository
        other_user = create(:user)
        other_credential = create(:credential, user: other_user, service_name: 'github')
        other_repository = create(:repository, user: other_user, github_credential: other_credential)

        get :new

        expect(assigns(:repositories)).to include(repository)
        expect(assigns(:repositories)).not_to include(other_repository)
      end

      it 'renders successfully' do
        get :new
        expect(response).to have_http_status(:success)
        expect(response.body).to include('Create New Epic')
      end
    end

    context 'when user is not authenticated' do
      before do
        sign_out user
      end

      it 'redirects to sign in page' do
        get :new
        expect(response).to redirect_to(new_user_session_path)
      end
    end
  end

  describe 'GET #show' do
    let(:epic) { create(:epic, user: user, repository: repository) }
    let!(:task1) { create(:task, epic: epic, description: 'Task 1', position: 1) }
    let!(:task2) { create(:task, epic: epic, description: 'Task 2', position: 2) }

    context 'when user is authenticated and owns the epic' do
      it 'returns http success' do
        get :show, params: { id: epic.id }
        expect(response).to have_http_status(:success)
      end

      it 'assigns the correct epic to @epic' do
        get :show, params: { id: epic.id }
        expect(assigns(:epic)).to eq(epic)
      end

      it 'includes tasks association' do
        # This test verifies that tasks are preloaded
        get :show, params: { id: epic.id }

        expect(assigns(:epic).tasks).to match_array([task1, task2])
      end

      it 'renders successfully' do
        get :show, params: { id: epic.id }
        expect(response).to have_http_status(:success)
        expect(response.body).to include(epic.title)
      end
    end

    context 'when user tries to access another user\'s epic' do
      let(:other_user) { create(:user) }
      let(:other_credential) { create(:credential, user: other_user, service_name: 'github') }
      let(:other_repository) { create(:repository, user: other_user, github_credential: other_credential) }
      let(:other_epic) { create(:epic, user: other_user, repository: other_repository) }

      it 'raises ActiveRecord::RecordNotFound' do
        expect {
          get :show, params: { id: other_epic.id }
        }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end

    context 'when epic does not exist' do
      it 'raises ActiveRecord::RecordNotFound' do
        expect {
          get :show, params: { id: 999999 }
        }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end

    context 'when user is not authenticated' do
      before do
        sign_out user
      end

      it 'redirects to sign in page' do
        get :show, params: { id: epic.id }
        expect(response).to redirect_to(new_user_session_path)
      end
    end
  end

  describe 'GET #index' do
    let!(:epic1) { create(:epic, user: user, repository: repository, title: 'Epic 1') }
    let!(:epic2) { create(:epic, user: user, repository: repository, title: 'Epic 2') }
    
    context 'when user is authenticated' do
      it 'returns http success' do
        get :index
        expect(response).to have_http_status(:success)
      end

      it 'assigns user epics to @epics' do
        get :index
        expect(assigns(:epics)).to match_array([epic1, epic2])
      end

      it 'orders epics by created_at descending' do
        epic1.update!(created_at: 2.days.ago)
        epic2.update!(created_at: 1.day.ago)
        
        get :index
        expect(assigns(:epics)).to eq([epic2, epic1])
      end

      it 'does not include other users epics' do
        other_user = create(:user)
        other_credential = create(:credential, user: other_user, service_name: 'github')
        other_repository = create(:repository, user: other_user, github_credential: other_credential)
        other_epic = create(:epic, user: other_user, repository: other_repository)

        get :index
        expect(assigns(:epics)).not_to include(other_epic)
      end

      it 'renders successfully' do
        get :index
        expect(response).to have_http_status(:success)
        expect(response.body).to include('All Epics')
      end
    end

    context 'when user is not authenticated' do
      before do
        sign_out user
      end

      it 'redirects to sign in page' do
        get :index
        expect(response).to redirect_to(new_user_session_path)
      end
    end
  end

  describe 'POST #dispatch_agent' do
    let(:cursor_credential) { create(:credential, user: user, service_name: 'cursor_agent') }
    let(:epic) { create(:epic, user: user, repository: repository, cursor_agent_credential: cursor_credential) }
    let!(:pending_task) { create(:task, epic: epic, status: 'pending', position: 1) }
    
    let(:mock_execute_result) { { task: pending_task, agent_id: 'test-agent-id', branch_name: 'test-branch' } }

    before do
      allow(Tasks::Services::Execute).to receive(:run!).and_return(mock_execute_result)
    end

    context 'when user is authenticated and owns the epic' do
      it 'dispatches the first pending task' do
        post :dispatch_agent, params: { id: epic.id }
        
        expect(Tasks::Services::Execute).to have_received(:run!).with(task: pending_task)
      end

      it 'redirects to epic show page with success notice' do
        post :dispatch_agent, params: { id: epic.id }
        
        expect(response).to redirect_to(epic_path(epic))
        expect(flash[:notice]).to match(/Agent dispatched successfully/)
      end

      context 'when there are no pending tasks' do
        before do
          pending_task.update!(status: 'completed')
        end

        it 'redirects with an alert' do
          post :dispatch_agent, params: { id: epic.id }
          
          expect(response).to redirect_to(epic_path(epic))
          expect(flash[:alert]).to match(/No pending tasks available/)
        end

        it 'does not call the execute service' do
          post :dispatch_agent, params: { id: epic.id }
          
          expect(Tasks::Services::Execute).not_to have_received(:run!)
        end
      end

      context 'when execution fails' do
        before do
          allow(Tasks::Services::Execute).to receive(:run!).and_raise(StandardError, 'Test error')
        end

        it 'redirects with error message' do
          post :dispatch_agent, params: { id: epic.id }
          
          expect(response).to redirect_to(epic_path(epic))
          expect(flash[:alert]).to match(/Failed to dispatch agent/)
          expect(flash[:alert]).to include('Test error')
        end
      end
    end

    context 'when user tries to dispatch agent for another user\'s epic' do
      let(:other_user) { create(:user) }
      let(:other_credential) { create(:credential, user: other_user, service_name: 'github') }
      let(:other_repository) { create(:repository, user: other_user, github_credential: other_credential) }
      let(:other_epic) { create(:epic, user: other_user, repository: other_repository) }

      it 'raises ActiveRecord::RecordNotFound' do
        expect {
          post :dispatch_agent, params: { id: other_epic.id }
        }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end

    context 'when user is not authenticated' do
      before do
        sign_out user
      end

      it 'redirects to sign in page' do
        post :dispatch_agent, params: { id: epic.id }
        expect(response).to redirect_to(new_user_session_path)
      end
    end
  end
end
