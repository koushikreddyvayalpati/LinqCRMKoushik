# frozen_string_literal: true

##
# Background job for syncing contacts to external CRM
# Handles individual contact sync with proper error handling and monitoring
##
class CrmSyncJob < ApplicationJob
  queue_as :crm_sync

  ##
  # Syncs a single contact to the external CRM
  # @param contact_id [Integer] The ID of the contact to sync
  ##
  def perform(contact_id)
    contact = Contact.find(contact_id)
    
    # Skip if already synced
    return if contact.acme_id.present?

    Rails.logger.info("Starting CRM sync for contact #{contact.id}: #{contact.email}")
    
    begin
      acme_service = AcmeCrmService.instance
      acme_data = contact.to_acme_format
      
      response = acme_service.push_contact(acme_data)
      
      if response["success"]
        contact.update!(
          acme_id: response["acme_id"],
          synced_at: Time.current
        )
        Rails.logger.info("Successfully synced contact #{contact.id} to CRM")
      else
        Rails.logger.error("CRM sync failed for contact #{contact.id}: #{response['error']}")
        raise StandardError, "CRM sync failed: #{response['error']}"
      end
      
    rescue AcmeCrmService::RateLimitError => e
      Rails.logger.warn("Rate limited, retrying contact #{contact.id} later")
      # Re-queue with delay
      CrmSyncJob.set(wait: 5.minutes).perform_later(contact_id)
      
    rescue AcmeCrmService::ServiceUnavailableError => e
      Rails.logger.error("CRM service unavailable for contact #{contact.id}")
      # Will be retried automatically by ApplicationJob
      raise e
      
    rescue => e
      Rails.logger.error("Unexpected error syncing contact #{contact.id}: #{e.message}")
      raise e
    end
  end
end 