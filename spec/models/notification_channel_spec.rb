require 'rails_helper'

RSpec.describe NotificationChannel, type: :model do
  describe 'associations' do
    it { is_expected.to belong_to(:user) }
  end

  describe 'validations' do
    it 'has a valid factory' do
      expect(build(:notification_channel)).to be_valid
    end

    it 'requires a service_name' do
      notification_channel = build(:notification_channel, service_name: nil)
      expect(notification_channel).not_to be_valid
      expect(notification_channel.errors[:service_name]).to include("can't be blank")
    end

    it 'requires a channel_id' do
      notification_channel = build(:notification_channel, channel_id: nil)
      expect(notification_channel).not_to be_valid
      expect(notification_channel.errors[:channel_id]).to include("can't be blank")
    end

    it 'requires unique channel_id per user and service_name' do
      user = create(:user)
      create(:notification_channel, user: user, service_name: 'telegram', channel_id: '12345')
      
      duplicate = build(:notification_channel, user: user, service_name: 'telegram', channel_id: '12345')
      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:channel_id]).to include("has already been taken")
    end

    it 'allows same channel_id for different users' do
      user1 = create(:user)
      user2 = create(:user)
      
      create(:notification_channel, user: user1, service_name: 'telegram', channel_id: '12345')
      different_user_channel = build(:notification_channel, user: user2, service_name: 'telegram', channel_id: '12345')
      
      expect(different_user_channel).to be_valid
    end

    it 'allows same channel_id for different service_names' do
      user = create(:user)
      
      create(:notification_channel, user: user, service_name: 'telegram', channel_id: '12345')
      different_service_channel = build(:notification_channel, user: user, service_name: 'slack', channel_id: '12345')
      
      expect(different_service_channel).to be_valid
    end
  end

  describe 'database columns' do
    it { is_expected.to have_db_column(:user_id).of_type(:integer).with_options(null: false) }
    it { is_expected.to have_db_column(:service_name).of_type(:string).with_options(null: false) }
    it { is_expected.to have_db_column(:channel_id).of_type(:string).with_options(null: false) }
    it { is_expected.to have_db_column(:created_at).of_type(:datetime).with_options(null: false) }
    it { is_expected.to have_db_column(:updated_at).of_type(:datetime).with_options(null: false) }
  end

  describe 'database indexes' do
    it { is_expected.to have_db_index([:user_id, :service_name, :channel_id]).unique }
  end

  describe 'creation' do
    it 'can be created with valid attributes' do
      user = create(:user)
      notification_channel = create(:notification_channel, 
        user: user, 
        service_name: 'telegram', 
        channel_id: '123456789'
      )
      
      expect(notification_channel).to be_persisted
      expect(notification_channel.user).to eq(user)
      expect(notification_channel.service_name).to eq('telegram')
      expect(notification_channel.channel_id).to eq('123456789')
    end
  end
end
