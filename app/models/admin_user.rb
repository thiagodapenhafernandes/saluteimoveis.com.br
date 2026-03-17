class AdminUser < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :recoverable, :rememberable, :validatable,
         :omniauthable, omniauth_providers: [:facebook]

  has_one_attached :avatar

  belongs_to :profile, optional: true
  belongs_to :manager, class_name: "AdminUser", optional: true
  has_many :subordinates, class_name: "AdminUser", foreign_key: "manager_id"
  has_many :habitations
  has_many :habitation_share_links, dependent: :destroy

  enum role: { editor: 0, admin: 1 }
  enum acting_type: { sales: 0, rentals: 1, both: 2 }
  
  validates :email, presence: true, uniqueness: true
  validates :name, presence: true
  
  def admin?
    role == 'admin' || profile&.admin?
  end

  def can?(action, resource)
    return true if admin?
    return false unless profile
    profile.can?(action, resource)
  end

  def subordinate_ids
    @subordinate_ids ||= [id] + subordinates.pluck(:id)
  end
end
