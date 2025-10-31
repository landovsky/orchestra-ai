class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable

  has_many :repositories, dependent: :destroy
  has_many :credentials, dependent: :destroy
  has_many :epics, dependent: :destroy
  has_many :notification_channels, dependent: :destroy
end
