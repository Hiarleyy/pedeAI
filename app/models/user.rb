class User < ApplicationRecord
  has_secure_password
  belongs_to :restaurant

  ROLES = %w[superAdmin admin funcionario].freeze
  DEFAULT_PERMISSIONS = %w[orders:read orders:update products:read].freeze

  validates :name, presence: true, length: { in: 2..120 }
  validates :email, presence: true, uniqueness: { case_sensitive: false }, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :role, inclusion: { in: ROLES }
  validates_text_encoding :name, :email
  validates :role, uniqueness: { scope: :restaurant_id, message: "já possui um superAdmin" }, if: :super_admin?

  normalizes :email, with: ->(email) { email.strip.downcase }

  before_update :keep_super_admin_role, if: :super_admin_role_changed?
  before_destroy :prevent_super_admin_removal

  def super_admin? = role == "superAdmin"
  def admin? = role == "admin"
  def funcionario? = role == "funcionario"

  def allowed?(permission)
    super_admin? || admin? || permissions.fetch(permission.to_s, false)
  end

  def api_token
    signed_id(purpose: :api_auth, expires_in: 24.hours)
  end

  private

  def super_admin_role_changed?
    role_in_database == "superAdmin" && role != "superAdmin"
  end

  def keep_super_admin_role
    errors.add(:role, "do superAdmin não pode ser alterado")
    throw :abort
  end

  def prevent_super_admin_removal
    return unless super_admin?

    errors.add(:base, "superAdmin do restaurante não pode ser removido")
    throw :abort
  end
end
