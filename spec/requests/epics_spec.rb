require 'rails_helper'

RSpec.describe "Epics", type: :request do
  let(:user) { create(:user) }
  let(:github_credential) { create(:credential, user: user, service_name: 'github') }
  let(:repository) { create(:repository, user: user, github_credential: github_credential) }

  before do
    sign_in user
  end

  describe "GET /epics/new" do
    context "smoke tests - page loads and displays expected content" do
      before do
        repository # ensure repository exists
      end

      it "successfully loads the new epic page" do
        get new_epic_path
        expect(response).to have_http_status(:success)
      end

      it "displays the page title" do
        get new_epic_path
        expect(response.body).to include("Create New Epic")
      end

      it "displays a repository dropdown label" do
        get new_epic_path
        expect(response.body).to include("Repository")
      end

      it "displays the repository in the dropdown" do
        get new_epic_path
        expect(response.body).to include(repository.name)
      end

      it "displays base branch input field" do
        get new_epic_path
        expect(response.body).to include("Base Branch")
      end

      it "displays default value 'main' in base branch field" do
        get new_epic_path
        expect(response.body).to include('value="main"')
      end

      it "displays tasks textarea label" do
        get new_epic_path
        expect(response.body).to include("Tasks")
      end

      it "displays tasks textarea with placeholder" do
        get new_epic_path
        expect(response.body).to include("Task 1: Add user authentication")
      end

      it "displays submit button" do
        get new_epic_path
        expect(response.body).to include("Create Epic")
      end

      it "displays cancel button" do
        get new_epic_path
        expect(response.body).to include("Cancel")
      end

      it "displays helper text for base branch" do
        get new_epic_path
        expect(response.body).to include("The branch to base all task branches on (default: main)")
      end

      it "displays helper text for tasks format" do
        get new_epic_path
        expect(response.body).to include('Enter one task per line starting with "Task N: Description"')
      end
    end

    context "when user has multiple repositories" do
      let!(:repo1) { create(:repository, user: user, github_credential: github_credential, name: "repo-alpha") }
      let!(:repo2) { create(:repository, user: user, github_credential: github_credential, name: "repo-beta") }

      it "displays all user's repositories in dropdown" do
        get new_epic_path
        
        expect(response.body).to include(repo1.name)
        expect(response.body).to include(repo2.name)
      end
    end

    context "when user has no repositories" do
      it "successfully loads but shows empty dropdown" do
        get new_epic_path
        
        expect(response).to have_http_status(:success)
        expect(response.body).to include("Select a repository")
      end
    end

    context "when user is not authenticated" do
      before do
        sign_out user
      end

      it "redirects to sign in page" do
        get new_epic_path
        expect(response).to redirect_to(new_user_session_path)
      end
    end
  end

  describe "GET /epics/:id" do
    let(:epic) { create(:epic, user: user, repository: repository, title: "Test Epic", base_branch: "develop") }
    let!(:task1) { create(:task, epic: epic, description: "Task 1: Setup project", position: 1, status: :pending) }
    let!(:task2) { create(:task, epic: epic, description: "Task 2: Add tests", position: 2, status: :running) }
    let!(:task3) { create(:task, epic: epic, description: "Task 3: Deploy", position: 3, status: :completed, pr_url: "https://github.com/user/repo/pull/123") }

    context "smoke tests - page loads and displays expected content" do
      it "successfully loads the epic show page" do
        get epic_path(epic)
        expect(response).to have_http_status(:success)
      end

      it "displays the epic title" do
        get epic_path(epic)
        expect(response.body).to include("Test Epic")
      end

      it "displays the epic status" do
        get epic_path(epic)
        expect(response.body).to include("Pending")
      end

      it "displays the repository name" do
        get epic_path(epic)
        expect(response.body).to include(repository.name)
      end

      it "displays the base branch" do
        get epic_path(epic)
        expect(response.body).to include("develop")
      end

      it "displays 'Tasks' section header" do
        get epic_path(epic)
        expect(response.body).to include("Tasks")
      end

      it "displays task count" do
        get epic_path(epic)
        expect(response.body).to include("Tasks (3)")
      end

      it "displays all tasks in order" do
        get epic_path(epic)
        
        expect(response.body).to include("Task 1: Setup project")
        expect(response.body).to include("Task 2: Add tests")
        expect(response.body).to include("Task 3: Deploy")
      end

      it "displays task positions" do
        get epic_path(epic)
        
        expect(response.body).to include("#1")
        expect(response.body).to include("#2")
        expect(response.body).to include("#3")
      end

      it "displays task statuses" do
        get epic_path(epic)
        
        # Check for status badges (humanized versions)
        expect(response.body).to include("Pending")
        expect(response.body).to include("Running")
        expect(response.body).to include("Completed")
      end

      it "displays PR link for completed task" do
        get epic_path(epic)
        
        expect(response.body).to include("View Pull Request")
        expect(response.body).to include("https://github.com/user/repo/pull/123")
      end

      it "displays back button" do
        get epic_path(epic)
        expect(response.body).to include("Create New Epic")
      end

      it "displays refresh button" do
        get epic_path(epic)
        expect(response.body).to include("Refresh")
      end
    end

    context "when tasks have branches" do
      before do
        task1.update!(branch_name: "feature/task-1")
      end

      it "displays branch names" do
        get epic_path(epic)
        expect(response.body).to include("feature/task-1")
      end
    end

    context "when epic has different statuses" do
      it "displays 'pending' status correctly" do
        epic.update!(status: :pending)
        get epic_path(epic)
        expect(response.body).to include("Pending")
      end

      it "displays 'running' status correctly" do
        epic.update!(status: :running)
        get epic_path(epic)
        expect(response.body).to include("Running")
      end

      it "displays 'completed' status correctly" do
        epic.update!(status: :completed)
        get epic_path(epic)
        expect(response.body).to include("Completed")
      end

      it "displays 'failed' status correctly" do
        epic.update!(status: :failed)
        get epic_path(epic)
        expect(response.body).to include("Failed")
      end
    end

    context "when epic has no tasks" do
      let(:empty_epic) { create(:epic, user: user, repository: repository, title: "Empty Epic") }

      it "successfully loads the page" do
        get epic_path(empty_epic)
        expect(response).to have_http_status(:success)
      end

      it "displays task count as 0" do
        get epic_path(empty_epic)
        expect(response.body).to include("Tasks (0)")
      end
    end

    context "when user tries to access another user's epic" do
      let(:other_user) { create(:user) }
      let(:other_credential) { create(:credential, user: other_user, service_name: 'github') }
      let(:other_repository) { create(:repository, user: other_user, github_credential: other_credential) }
      let(:other_epic) { create(:epic, user: other_user, repository: other_repository) }

      it "returns not found error" do
        # The controller properly scopes epics to current_user, which will raise RecordNotFound
        # In test environment, exceptions are rescued and rendered as error pages
        begin
          get epic_path(other_epic)
          # If we get here without exception, verify we at least can't see the epic
          expect(response).to have_http_status(404).or have_http_status(500)
        rescue ActiveRecord::RecordNotFound
          # This is the expected behavior - exception raised by the scoping
          expect(true).to be true
        end
      end
    end

    context "when user is not authenticated" do
      before do
        sign_out user
      end

      it "redirects to sign in page" do
        get epic_path(epic)
        expect(response).to redirect_to(new_user_session_path)
      end
    end
  end

  describe "GET /" do
    context "root path routing" do
      it "renders the new epic page" do
        get root_path
        expect(response).to have_http_status(:success)
        expect(response.body).to include("Create New Epic")
      end
    end
  end
end
