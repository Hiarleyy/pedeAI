class PlatformUser < ApplicationRecord
  has_secure_password
  has_many :platform_audit_events, dependent: :nullify

  ROLES = %w[owner operator support auditor read_only].freeze
  PERMISSIONS = {
    "owner" => %w[restaurants:read restaurants:create restaurants:update restaurants:lifecycle audits:read diagnostics:read],
    "operator" => %w[restaurants:read restaurants:create restaurants:update restaurants:lifecycle diagnostics:read],
    "support" => %w[restaurants:read diagnostics:read],
    "auditor" => %w[restaurants:read audits:read diagnostics:read],
    "read_only" => %w[restaurants:read diagnostics:read]
  }.freeze

  normalizes :email, with: ->(email) { email.strip.downcase }
  validates :name, presence: true, length: { in: 2..120 }
  validates :email, presence: true, uniqueness: { case_sensitive: false }, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :role, inclusion: { in: ROLES }

  def allowed?(permission) = PERMISSIONS.fetch(role, []).include?(permission.to_s)

  def api_token
    signed_id(purpose: :platform_auth, expires_in: 2.hours)
  end
end
