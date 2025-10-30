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

      it 'renders the new template' do
        get :new
        expect(response).to render_template(:new)
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

      it 'renders the show template' do
        get :show, params: { id: epic.id }
        expect(response).to render_template(:show)
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
end
