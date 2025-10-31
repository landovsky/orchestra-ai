require 'rails_helper'

RSpec.describe Repository, type: :model do
  describe 'associations' do
    it { is_expected.to belong_to(:user) }
    it { is_expected.to belong_to(:github_credential).class_name('Credential') }
  end

  describe 'validations' do
    let(:user) { create(:user) }
    let(:credential) { create(:credential, user: user, service_name: 'github') }

    it 'has a valid factory' do
      expect(build(:repository)).to be_valid
    end

    it 'requires a name' do
      repository = build(:repository, name: nil)
      expect(repository).not_to be_valid
      expect(repository.errors[:name]).to include("can't be blank")
    end

    it 'requires a github_url' do
      repository = build(:repository, github_url: nil)
      expect(repository).not_to be_valid
      expect(repository.errors[:github_url]).to include("can't be blank")
    end

    it 'requires a unique name per user' do
      create(:repository, user: user, name: 'my-repo')
      repository = build(:repository, user: user, name: 'my-repo')
      expect(repository).not_to be_valid
      expect(repository.errors[:name]).to include("has already been taken")
    end

    it 'allows same name for different users' do
      user2 = create(:user, email: 'user2@example.com')
      create(:repository, user: user, name: 'my-repo')
      repository = build(:repository, user: user2, name: 'my-repo')
      expect(repository).to be_valid
    end
  end

  describe 'database columns' do
    it { is_expected.to have_db_column(:user_id).of_type(:integer).with_options(null: false) }
    it { is_expected.to have_db_column(:name).of_type(:string).with_options(null: false) }
    it { is_expected.to have_db_column(:github_url).of_type(:string).with_options(null: false) }
    it { is_expected.to have_db_column(:github_credential_id).of_type(:integer).with_options(null: false) }
    it { is_expected.to have_db_column(:created_at).of_type(:datetime).with_options(null: false) }
    it { is_expected.to have_db_column(:updated_at).of_type(:datetime).with_options(null: false) }
  end

  describe 'database indexes' do
    it { is_expected.to have_db_index([:user_id, :name]).unique }
    it { is_expected.to have_db_index(:user_id) }
    it { is_expected.to have_db_index(:github_credential_id) }
  end

  describe 'creation' do
    let(:user) { create(:user) }
    let(:credential) { create(:credential, user: user, service_name: 'github') }

    it 'can be created with valid attributes' do
      repository = create(:repository, 
        user: user, 
        github_credential: credential,
        name: 'test-repo',
        github_url: 'https://github.com/user/test-repo'
      )
      expect(repository).to be_persisted
      expect(repository.name).to eq('test-repo')
      expect(repository.github_url).to eq('https://github.com/user/test-repo')
    end
  end
end
