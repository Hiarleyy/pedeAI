class PlatformAuditEvent < ApplicationRecord
  belongs_to :platform_user, optional: true

  OUTCOMES = %w[success failure denied].freeze
  validates :action, presence: true
  validates :outcome, inclusion: { in: OUTCOMES }

  before_update :prevent_mutation
  before_destroy :prevent_mutation

  private

  def prevent_mutation
    errors.add(:base, "Audit events are append-only")
    throw :abort
  end
end
