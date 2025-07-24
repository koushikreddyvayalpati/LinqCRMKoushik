# frozen_string_literal: true

##
# API::V1::ContactsController handles contact management operations
# Integrates with AcmeCRM while maintaining our normalized data format
# Provides secure endpoints with JWT authentication
##
class Api::V1::ContactsController < ApplicationController
  include Authentication

  # Error handling
  rescue_from AcmeCrmService::AcmeCrmError, with: :handle_acme_crm_error
  rescue_from ActiveRecord::RecordInvalid, with: :handle_validation_error
  rescue_from ActiveRecord::RecordNotFound, with: :handle_not_found_error

  ##
  # GET /api/v1/contacts
  # Retrieves contacts with optional filtering and pagination
  ##
  def index
    begin
      # Parse query parameters
      filters = parse_index_filters
      
      # Get contacts from local database
      contacts = Contact.recent
                       .limit(filters[:limit] || 50)
                       .offset(filters[:offset] || 0)

      # Apply filters if provided
      contacts = contacts.by_company(filters[:company]) if filters[:company].present?

      # Optionally sync with AcmeCRM
      if params[:sync_with_acme] == "true"
        sync_contacts_from_acme(filters)
      end

      render json: {
        success: true,
        contacts: contacts.map(&:as_json),
        meta: {
          total: contacts.count,
          limit: filters[:limit] || 50,
          offset: filters[:offset] || 0,
          synced_with_acme: params[:sync_with_acme] == "true"
        }
      }, status: :ok

    rescue => e
      Rails.logger.error("Error in contacts#index: #{e.message}")
      render_error("Failed to retrieve contacts", :internal_server_error)
    end
  end

  ##
  # POST /api/v1/contacts
  # Creates a new contact and pushes it to AcmeCRM
  ##
  def create
    begin
      # Extract user info from JWT token
      created_by = current_user_payload[:user_id] || current_user_payload[:email] || "unknown"

      # Create contact from request parameters
      contact = Contact.new(contact_params.merge(created_by: created_by))

      # Validate and save locally first
      if contact.save
        # Queue background job for CRM sync - much faster response
        CrmSyncJob.perform_later(contact.id)

        Rails.logger.info("Successfully created contact: #{contact.email}")
        
        render json: {
          success: true,
          message: "Contact created and queued for CRM sync",
          contact: contact.as_json,
          acme_sync: "queued"
        }, status: :created

      else
        render_validation_errors(contact.errors)
      end

    rescue => e
      Rails.logger.error("Error in contacts#create: #{e.message}")
      render_error("Failed to create contact", :internal_server_error)
    end
  end

  ##
  # POST /api/v1/contacts/bulk
  # Creates multiple contacts efficiently
  ##
  def bulk_create
    begin
      created_by = current_user_payload[:user_id] || current_user_payload[:email] || "unknown"
      contacts_params = params.require(:contacts)
      
      unless contacts_params.is_a?(Array)
        return render_error("Contacts must be an array", :bad_request)
      end

      if contacts_params.length > 100
        return render_error("Maximum 100 contacts per bulk request", :bad_request)
      end

      contacts = []
      errors = []

      # Process each contact
      contacts_params.each_with_index do |contact_data, index|
        contact = Contact.new(contact_data.permit(
          :first_name, :last_name, :email, :phone, 
          :company, :title, :linkedin_url, :notes
        ).merge(created_by: created_by))

        if contact.valid?
          contacts << contact
        else
          errors << {
            index: index,
            email: contact_data[:email],
            errors: contact.errors.full_messages
          }
        end
      end

      # Save valid contacts in a transaction
      saved_contacts = []
      Contact.transaction do
        contacts.each do |contact|
          if contact.save
            saved_contacts << contact
            # Queue for background sync
            CrmSyncJob.perform_later(contact.id)
          end
        end
      end

      Rails.logger.info("Bulk created #{saved_contacts.size} contacts, #{errors.size} errors")

      render json: {
        success: true,
        message: "Bulk contact creation completed",
        created: saved_contacts.size,
        errors: errors.size,
        contacts: saved_contacts.map(&:as_json),
        validation_errors: errors
      }, status: :created

    rescue => e
      Rails.logger.error("Error in contacts#bulk_create: #{e.message}")
      render_error("Failed to create contacts", :internal_server_error)
    end
  end

  private

  ##
  # Strong parameters for contact creation/updates
  ##
  def contact_params
    params.require(:contact).permit(
      :first_name, :last_name, :email, :phone, 
      :company, :title, :linkedin_url, :notes
    )
  end

  ##
  # Parses and validates filters for the index action
  ##
  def parse_index_filters
    {
      limit: [params[:limit]&.to_i || 50, 100].min, # Cap at 100
      offset: [params[:offset]&.to_i || 0, 0].max,   # Ensure non-negative
      company: params[:company]&.strip
    }
  end

  ##
  # Pushes contact to AcmeCRM with error handling
  ##
  def push_to_acme_crm(contact)
    acme_service = AcmeCrmService.instance
    acme_data = contact.to_acme_format
    
    response = acme_service.push_contact(acme_data)
    Rails.logger.info("AcmeCRM sync successful for contact: #{contact.email}")
    response

  rescue AcmeCrmService::ValidationError => e
    Rails.logger.warn("AcmeCRM validation error: #{e.message}")
    { "success" => false, "error" => "CRM validation failed" }
    
  rescue AcmeCrmService::AcmeCrmError => e
    Rails.logger.error("AcmeCRM error: #{e.message}")
    { "success" => false, "error" => "CRM service unavailable" }
  end

  ##
  # Syncs contacts from AcmeCRM to local database
  ##
  def sync_contacts_from_acme(filters)
    acme_service = AcmeCrmService.instance
    acme_filters = { limit: filters[:limit] }
    acme_filters[:company] = filters[:company] if filters[:company]

    acme_response = acme_service.get_contacts(acme_filters)
    
    if acme_response["success"] && acme_response["contacts"]
      acme_response["contacts"].each do |acme_contact|
        sync_single_contact_from_acme(acme_contact)
      end
    end

  rescue AcmeCrmService::AcmeCrmError => e
    Rails.logger.warn("Failed to sync from AcmeCRM: #{e.message}")
  end

  ##
  # Syncs a single contact from AcmeCRM format
  ##
  def sync_single_contact_from_acme(acme_contact)
    existing_contact = Contact.find_by(
      email: acme_contact["acme_email"] || acme_contact[:acme_email]
    )

    unless existing_contact
      created_by = current_user_payload[:user_id] || "acme_sync"
      contact = Contact.from_acme_format(acme_contact, created_by: created_by)
      contact.save if contact.valid?
    end
  end

  ##
  # Error Handlers
  ##

  def handle_acme_crm_error(error)
    case error
    when AcmeCrmService::AuthenticationError
      render_error("CRM authentication failed", :unauthorized)
    when AcmeCrmService::RateLimitError
      render_error("Rate limit exceeded. Please try again later.", :too_many_requests)
    when AcmeCrmService::ServiceUnavailableError
      render_error("CRM service temporarily unavailable", :service_unavailable)
    else
      render_error("CRM integration error", :bad_gateway)
    end
  end

  def handle_validation_error(error)
    render_validation_errors(error.record.errors)
  end

  def handle_not_found_error
    render_error("Contact not found", :not_found)
  end

  ##
  # Response Helpers
  ##

  def render_error(message, status)
    render json: {
      success: false,
      error: message,
      status: Rack::Utils::SYMBOL_TO_STATUS_CODE[status]
    }, status: status
  end

  def render_validation_errors(errors)
    render json: {
      success: false,
      error: "Validation failed",
      details: errors.full_messages,
      field_errors: errors.messages
    }, status: :unprocessable_entity
  end
end
