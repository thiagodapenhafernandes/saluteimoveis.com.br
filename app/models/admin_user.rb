class AdminUser < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :recoverable, :rememberable, :validatable

  enum role: { editor: 0, admin: 1 }
  
  validates :email, presence: true, uniqueness: true
  validates :name, presence: true
  
  def admin?
    role == 'admin'
  end
end
