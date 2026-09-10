class Restaurant < ApplicationRecord
  has_many :users, dependent: :restrict_with_error
  has_many :categories, dependent: :restrict_with_error
  has_many :products, dependent: :restrict_with_error
  has_many :orders, dependent: :restrict_with_error

  SUPPORTED_FONTS = %w[inter roboto montserrat poppins playfair-display open-sans].freeze
  MENU_INFORMATION_DEFAULTS = {
    "timezone" => "America/Sao_Paulo",
    "hours" => {},
    "delivery" => { "estimate" => "", "fee" => nil },
    "location" => { "address" => "", "map_url" => "" },
    "contact" => { "phone" => "", "whatsapp" => "" },
    "social" => { "instagram" => "", "facebook" => "", "website" => "" },
    "visibility" => { "operating" => false, "delivery" => false, "location" => false, "contact" => false, "social" => false }
  }.freeze
  MENU_INFORMATION_GROUPS = %w[operating delivery location contact social].freeze

  before_validation :build_slug, on: :create
  validates :name, presence: true, length: { in: 2..120 }
  validates :slug, presence: true, uniqueness: true, format: { with: /\A[a-z0-9]+(?:-[a-z0-9]+)*\z/ }
  validates :menu_description, length: { maximum: 500 }, allow_blank: true
  validates :primary_color, format: { with: /\A#[0-9a-fA-F]{6}\z/ }
  validates :font_family, inclusion: { in: SUPPORTED_FONTS }
  validates_text_encoding :name, :menu_description, :banner_url, :logo_url, :product_placeholder_url, :menu_information
  validate :menu_information_is_valid

  def menu_information
    persisted_information = self[:menu_information]
    MENU_INFORMATION_DEFAULTS.deep_merge(persisted_information.is_a?(Hash) ? persisted_information : {})
  end

  def menu_information_status(now: Time.current)
    information = menu_information
    timezone = ActiveSupport::TimeZone[information["timezone"]] || ActiveSupport::TimeZone["America/Sao_Paulo"]
    local_time = now.in_time_zone(timezone)
    active = [local_time.to_date, local_time.to_date - 1.day].flat_map do |date|
      Array(information.dig("hours", date.wday.to_s)).filter_map do |interval|
        next unless interval.is_a?(Hash) && interval["enabled"] != false
        opening = parse_local_time(date, interval["open"], timezone)
        closing = parse_local_time(date, interval["close"], timezone)
        next unless opening && closing
        closing += 1.day if closing <= opening
        [opening, closing]
      end
    end.find { |opening, closing| local_time >= opening && local_time < closing }

    if active
      { "open" => true, "closes_at" => active.last.strftime("%H:%M"), "opens_at" => nil }
    else
      { "open" => false, "closes_at" => nil, "opens_at" => next_opening_after(local_time, timezone) }
    end
  end

  def as_json(options = nil)
    super(options).merge("menu_information" => menu_information, "menu_information_status" => menu_information_status)
  end

  private

  def build_slug
    self.slug = name.to_s.parameterize if slug.blank?
  end

  def menu_information_is_valid
    information = menu_information
    errors.add(:menu_information, "must use a valid IANA timezone") unless ActiveSupport::TimeZone[information["timezone"]]
    visibility = information["visibility"]
    errors.add(:menu_information, "has invalid visibility settings") unless visibility.is_a?(Hash) && MENU_INFORMATION_GROUPS.all? { |group| [true, false].include?(visibility[group]) }
    fee = information.dig("delivery", "fee")
    errors.add(:menu_information, "delivery fee must be non-negative") if fee.present? && (!fee.is_a?(Numeric) || fee.negative?)
    %w[map_url instagram facebook website].each do |key|
      value = information.dig(key == "map_url" ? "location" : "social", key)
      errors.add(:menu_information, "#{key} must be an HTTPS URL") if value.present? && !https_url?(value)
    end
    information["hours"].each do |weekday, intervals|
      valid_weekday = weekday.to_s.match?(/\A[0-6]\z/)
      valid_intervals = Array(intervals).all? { |interval| interval.is_a?(Hash) && valid_clock?(interval["open"]) && valid_clock?(interval["close"]) }
      errors.add(:menu_information, "has invalid operating hours") unless valid_weekday && valid_intervals
    end
  end

  def https_url?(value)
    URI.parse(value).is_a?(URI::HTTPS)
  rescue URI::InvalidURIError
    false
  end

  def valid_clock?(value)
    value.is_a?(String) && value.match?(/\A(?:[01]\d|2[0-3]):[0-5]\d\z/)
  end

  def parse_local_time(date, value, timezone)
    return unless valid_clock?(value)
    timezone.parse("#{date} #{value}")
  end

  def next_opening_after(local_time, timezone)
    7.times do |offset|
      date = local_time.to_date + offset.days
      Array(menu_information.dig("hours", date.wday.to_s)).each do |interval|
        next unless interval.is_a?(Hash) && interval["enabled"] != false
        opening = parse_local_time(date, interval["open"], timezone)
        return opening.strftime("%H:%M") if opening && opening > local_time
      end
    end
    nil
  end
end
