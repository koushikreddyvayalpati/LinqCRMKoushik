# frozen_string_literal: true

##
# Contact model representing normalized contact data from various CRM sources
# Handles validation, normalization, and business logic for contact management
##
class Contact < ApplicationRecord
  # Validations
  validates :first_name, presence: true, length: { maximum: 100 }
  validates :last_name, presence: true, length: { maximum: 100 }
  validates :email, presence: true, 
                   format: { with: URI::MailTo::EMAIL_REGEXP, message: "Invalid email format" },
                   uniqueness: { case_sensitive: false }
  validates :phone, length: { maximum: 20 }
  validates :company, length: { maximum: 200 }
  validates :title, length: { maximum: 150 }
  validates :acme_id, uniqueness: { allow_blank: true }
  validates :linkedin_url, format: { 
    with: %r{\Ahttps?://(?:www\.)?linkedin\.com/.*\z}i, 
    message: "Invalid LinkedIn URL format" 
  }, allow_blank: true
  validates :created_by, presence: true

  # Scopes for common queries
  scope :by_company, ->(company) { where(company: company) }
  scope :recent, -> { order(created_at: :desc) }
  scope :with_acme_id, -> { where.not(acme_id: nil) }
  scope :synced, -> { where.not(acme_id: nil, synced_at: nil) }
  scope :pending_sync, -> { where(acme_id: nil) }

  # Callbacks
  before_save :normalize_data
  before_validation :strip_whitespace

  ##
  # Returns the full name of the contact
  # @return [String] Formatted full name
  ##
#   def full_name
#     "#{first_name} #{last_name}".strip
#   end
    def full_name
        "#{first_name}" "#{last_name}".strip
    end

  ##
  # Converts contact to AcmeCRM format for external API calls
  # @return [Hash] Contact data in AcmeCRM format
  ##
  def to_acme_format
    {
      acme_first_name: first_name,
      acme_last_name: last_name,
      acme_email: email,
      acme_phone: phone,
      acme_company: company,
      acme_job_title: title,
      acme_linkedin: linkedin_url,
      acme_notes: notes,
      acme_source: "Linq QR Scan"
    }
  end

  ##
  # Creates a contact from AcmeCRM format data
  # @param acme_data [Hash] Contact data from AcmeCRM
  # @param created_by [String] ID or identifier of who created the contact
  # @return [Contact] New contact instance
  ##
  def self.from_acme_format(acme_data, created_by:)
    new(
      first_name: acme_data["acme_first_name"] || acme_data[:acme_first_name],
      last_name: acme_data["acme_last_name"] || acme_data[:acme_last_name],
      email: acme_data["acme_email"] || acme_data[:acme_email],
      phone: acme_data["acme_phone"] || acme_data[:acme_phone],
      company: acme_data["acme_company"] || acme_data[:acme_company],
      title: acme_data["acme_job_title"] || acme_data[:acme_job_title],
      linkedin_url: acme_data["acme_linkedin"] || acme_data[:acme_linkedin],
      notes: acme_data["acme_notes"] || acme_data[:acme_notes],
      acme_id: acme_data["acme_id"] || acme_data[:acme_id],
      created_by: created_by
    )
  end

  ##
  # Returns the sync status for display
  # @return [String] Current sync status
  ##
  def sync_status
    return "synced" if acme_id.present? && synced_at.present?
    return "pending" if acme_id.blank?
    return "partial" # Has acme_id but no synced_at timestamp
  end

  ##
  # JSON representation for API responses
  # @return [Hash] Contact data for JSON serialization
  ##
  def as_json(options = {})
    super(options.merge(
      except: [:acme_id, :created_by],
      methods: [:full_name, :sync_status]
    ))
  end

  private

  ##
  # Normalizes data before saving
  ##
  def normalize_data
    self.email = email&.downcase
    self.first_name = first_name&.titleize
    self.last_name = last_name&.titleize
    self.company = company&.titleize
  end

  ##
  # Strips whitespace from string attributes
  ##
  def strip_whitespace
    string_attributes = %w[first_name last_name email phone company title linkedin_url notes]
    string_attributes.each do |attr|
      value = send(attr)
      send("#{attr}=", value&.strip)
    end
  end
end
