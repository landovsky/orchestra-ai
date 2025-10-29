require 'rails_helper'

RSpec.describe Epic, type: :model do
  describe 'associations' do
    it { is_expected.to belong_to(:user) }
    it { is_expected.to belong_to(:repository) }
    it { is_expected.to belong_to(:llm_credential).class_name('Credential').optional }
    it { is_expected.to belong_to(:cursor_agent_credential).class_name('Credential').optional }
    it { is_expected.to have_many(:tasks).dependent(:destroy) }
  end

  describe 'validations' do
    let(:user) { create(:user) }
    let(:repository) { create(:repository, user: user) }

    it 'has a valid factory' do
      expect(build(:epic)).to be_valid
    end

    it 'requires a title' do
      epic = build(:epic, title: nil)
      expect(epic).not_to be_valid
      expect(epic.errors[:title]).to include("can't be blank")
    end

    it 'requires a user' do
      epic = build(:epic, user: nil)
      expect(epic).not_to be_valid
      expect(epic.errors[:user]).to include("must exist")
    end

    it 'requires a repository' do
      epic = build(:epic, repository: nil)
      expect(epic).not_to be_valid
      expect(epic.errors[:repository]).to include("must exist")
    end
  end

  describe 'enums' do
    it { is_expected.to define_enum_for(:status).with_values(
      pending: 0,
      generating_spec: 1,
      running: 2,
      paused: 3,
      completed: 4,
      failed: 5
    ).backed_by_column_of_type(:integer) }

    it 'defaults to pending status' do
      epic = Epic.new
      expect(epic.status).to eq('pending')
    end

    it 'can be set to generating_spec' do
      epic = create(:epic, status: :generating_spec)
      expect(epic.status).to eq('generating_spec')
      expect(epic.generating_spec?).to be true
    end

    it 'can be set to running' do
      epic = create(:epic, status: :running)
      expect(epic.status).to eq('running')
      expect(epic.running?).to be true
    end

    it 'can be set to paused' do
      epic = create(:epic, status: :paused)
      expect(epic.status).to eq('paused')
      expect(epic.paused?).to be true
    end

    it 'can be set to completed' do
      epic = create(:epic, status: :completed)
      expect(epic.status).to eq('completed')
      expect(epic.completed?).to be true
    end

    it 'can be set to failed' do
      epic = create(:epic, status: :failed)
      expect(epic.status).to eq('failed')
      expect(epic.failed?).to be true
    end
  end

  describe 'database columns' do
    it { is_expected.to have_db_column(:user_id).of_type(:integer).with_options(null: false) }
    it { is_expected.to have_db_column(:repository_id).of_type(:integer).with_options(null: false) }
    it { is_expected.to have_db_column(:llm_credential_id).of_type(:integer) }
    it { is_expected.to have_db_column(:cursor_agent_credential_id).of_type(:integer) }
    it { is_expected.to have_db_column(:title).of_type(:string) }
    it { is_expected.to have_db_column(:prompt).of_type(:text) }
    it { is_expected.to have_db_column(:base_branch).of_type(:string) }
    it { is_expected.to have_db_column(:status).of_type(:integer).with_options(null: false, default: 0) }
    it { is_expected.to have_db_column(:created_at).of_type(:datetime).with_options(null: false) }
    it { is_expected.to have_db_column(:updated_at).of_type(:datetime).with_options(null: false) }
  end

  describe 'database indexes' do
    it { is_expected.to have_db_index(:user_id) }
    it { is_expected.to have_db_index(:repository_id) }
    it { is_expected.to have_db_index(:llm_credential_id) }
    it { is_expected.to have_db_index(:cursor_agent_credential_id) }
    it { is_expected.to have_db_index(:status) }
  end

  describe 'creation' do
    let(:user) { create(:user) }
    let(:repository) { create(:repository, user: user) }
    let(:llm_credential) { create(:credential, user: user, service_name: 'openai') }
    let(:cursor_credential) { create(:credential, user: user, service_name: 'cursor_agent') }

    it 'can be created with valid attributes' do
      epic = create(:epic,
        user: user,
        repository: repository,
        llm_credential: llm_credential,
        cursor_agent_credential: cursor_credential,
        title: 'Test Epic',
        prompt: 'Build a new feature',
        base_branch: 'main'
      )
      expect(epic).to be_persisted
      expect(epic.title).to eq('Test Epic')
      expect(epic.prompt).to eq('Build a new feature')
      expect(epic.base_branch).to eq('main')
      expect(epic.status).to eq('pending')
    end

    it 'can be created without optional credential references' do
      epic = create(:epic,
        user: user,
        repository: repository,
        llm_credential: nil,
        cursor_agent_credential: nil,
        title: 'Test Epic'
      )
      expect(epic).to be_persisted
      expect(epic.llm_credential).to be_nil
      expect(epic.cursor_agent_credential).to be_nil
    end
  end
end
