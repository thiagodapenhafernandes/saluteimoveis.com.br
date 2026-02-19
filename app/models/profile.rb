class Profile < ApplicationRecord
  has_many :admin_users
  
  validates :name, presence: true, uniqueness: true

  def admin?
    name == 'Administrador' || (permissions || {})['admin'] == true
  end

  def can?(action, resource)
    return true if admin?
    perms = permissions || {}
    # Structure: { "leads" => { "read" => true, "write" => false } }
    perms.dig(resource.to_s, action.to_s) == true
  end
end
