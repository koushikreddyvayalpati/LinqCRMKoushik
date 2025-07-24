# frozen_string_literal: true

##
# Base class for all background jobs
# Handles retry logic and error reporting
##
class ApplicationJob < ActiveJob::Base
  # Automatically retry jobs that fail due to network issues
  retry_on StandardError, wait: :exponentially_longer, attempts: 3
  
  # Don't retry certain types of errors
  discard_on ActiveRecord::RecordNotFound
  discard_on AcmeCrmService::ValidationError
end
