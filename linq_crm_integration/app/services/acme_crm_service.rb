# frozen_string_literal: true

# Handles all the fake "external CRM" stuff for the demo.
# In a real app, this would talk to a real API. Here, it's all mocked.
class AcmeCrmService
  include Singleton

  # Configuration
  BASE_URL = ENV.fetch("ACME_CRM_BASE_URL", "https://api.acmecrm.com/v1")
  API_KEY = ENV.fetch("ACME_CRM_API_KEY", "mock_api_key_for_demo")
  TIMEOUT = 30.seconds
  RETRY_COUNT = 3
  
  # Rate limiting awareness
  RATE_LIMIT_PER_MINUTE = 100
  RATE_LIMIT_WINDOW = 1.minute

  # Custom error classes
  class AcmeCrmError < StandardError; end
  class AuthenticationError < AcmeCrmError; end
  class ValidationError < AcmeCrmError; end
  class RateLimitError < AcmeCrmError; end
  class ServiceUnavailableError < AcmeCrmError; end

  def initialize
    @client = Faraday.new(
      url: BASE_URL,
      headers: {
        "Content-Type" => "application/json",
        "Authorization" => "Bearer #{API_KEY}",
        "User-Agent" => "Linq-Integration/1.0"
      }
    ) do |config|
      config.request :json
      config.response :json
      config.adapter Faraday.default_adapter
      config.options.timeout = TIMEOUT
      config.options.open_timeout = 10
      
      # Add retry middleware
      config.request :retry, {
        max: RETRY_COUNT,
        interval: 0.5,
        backoff_factor: 2,
        retry_statuses: [429, 500, 502, 503, 504]
      }
    end
    
    # Initialize rate limiting tracking
    @request_timestamps = []
  end

  # Pretend to push a contact to AcmeCRM (just returns a fake response in demo mode)
  def push_contact(contact_data)
    Rails.logger.info("Pushing contact to AcmeCRM: #{contact_data[:acme_email]}")

    # In demo mode, return a mock response
    return mock_push_response(contact_data) if demo_mode?

    # Check rate limiting before making request
    check_rate_limit!

    response = @client.post("/contacts", contact_data)
    track_request!
    handle_response(response, "push contact")
  rescue Faraday::TimeoutError
    raise ServiceUnavailableError, "AcmeCRM service is currently unavailable (timeout)"
  rescue Faraday::ConnectionFailed
    raise ServiceUnavailableError, "Unable to connect to AcmeCRM service"
  end

  ##
  # Retrieves contacts from AcmeCRM with optional filtering
  # @param filters [Hash] Optional filters (company, limit, etc.)
  # @return [Array<Hash>] Array of contact data from AcmeCRM
  # @raise [AcmeCrmError] If the API request fails
  ##
  def get_contacts(filters = {})
    Rails.logger.info("Retrieving contacts from AcmeCRM with filters: #{filters}")

    # In demo mode, return mock data
    return mock_contacts_response(filters) if demo_mode?

    response = @client.get("/contacts", filters)
    handle_response(response, "get contacts")
  rescue Faraday::TimeoutError
    raise ServiceUnavailableError, "AcmeCRM service is currently unavailable (timeout)"
  rescue Faraday::ConnectionFailed
    raise ServiceUnavailableError, "Unable to connect to AcmeCRM service"
  end

  ##
  # Retrieves a specific contact by AcmeCRM ID
  # @param acme_id [String] The AcmeCRM contact ID
  # @return [Hash] Contact data from AcmeCRM
  ##
  def get_contact(acme_id)
    Rails.logger.info("Retrieving contact from AcmeCRM: #{acme_id}")

    return mock_contact_response(acme_id) if demo_mode?

    response = @client.get("/contacts/#{acme_id}")
    handle_response(response, "get contact")
  rescue Faraday::TimeoutError
    raise ServiceUnavailableError, "AcmeCRM service is currently unavailable (timeout)"
  rescue Faraday::ConnectionFailed
    raise ServiceUnavailableError, "Unable to connect to AcmeCRM service"
  end

  ##
  # Class method to get the singleton instance
  ##
  def self.instance
    @instance ||= new
  end

  private

  ##
  # Checks if we're within rate limits, raises error if not
  ##
  def check_rate_limit!
    now = Time.current
    # Remove timestamps older than the window
    @request_timestamps.reject! { |timestamp| timestamp < now - RATE_LIMIT_WINDOW }
    
    if @request_timestamps.size >= RATE_LIMIT_PER_MINUTE
      raise RateLimitError, "Rate limit exceeded: #{RATE_LIMIT_PER_MINUTE} requests per minute"
    end
  end

  ##
  # Tracks the current request timestamp
  ##
  def track_request!
    @request_timestamps << Time.current
  end

  ##
  # Handles HTTP response and raises appropriate errors
  # @param response [Faraday::Response] The HTTP response
  # @param action [String] Description of the action for error messages
  # @return [Hash] Parsed response body
  ##
  def handle_response(response, action)
    case response.status
    when 200, 201
      response.body
    when 400
      raise ValidationError, "Invalid data sent to AcmeCRM while trying to #{action}"
    when 401
      raise AuthenticationError, "Authentication failed with AcmeCRM"
    when 429
      raise RateLimitError, "Rate limit exceeded for AcmeCRM API"
    when 500..599
      raise ServiceUnavailableError, "AcmeCRM service error while trying to #{action}"
    else
      raise AcmeCrmError, "Unexpected response from AcmeCRM: #{response.status}"
    end
  end

  ##
  # Checks if we're in demo mode (no real API key or test environment)
  ##
  def demo_mode?
    API_KEY == "mock_api_key_for_demo" || Rails.env.test?
  end

  ##
  # Returns a mock response for pushing contacts (demo mode)
  ##
  def mock_push_response(contact_data)
    {
      "success" => true,
      "acme_id" => "acme_#{SecureRandom.hex(8)}",
      "message" => "Contact created successfully",
      "contact" => contact_data.merge("acme_id" => "acme_#{SecureRandom.hex(8)}")
    }
  end

  ##
  # Returns mock contacts data (demo mode)
  ##
  def mock_contacts_response(filters)
    limit = filters[:limit] || 5
    
    # Pre-defined mock contacts from AcmeCRM (simulating data that exists in external CRM)
    mock_contacts = [
      {
        "acme_id" => "acme_12345",
        "acme_first_name" => "Sarah",
        "acme_last_name" => "Johnson",
        "acme_email" => "sarah.johnson@techcorp.com",
        "acme_phone" => "+1-555-987-6543",
        "acme_company" => "TechCorp Solutions",
        "acme_job_title" => "CTO",
        "acme_linkedin" => "https://linkedin.com/in/sarahjohnson",
        "acme_notes" => "Existing contact in AcmeCRM",
        "acme_source" => "Conference Lead"
      },
      {
        "acme_id" => "acme_67890",
        "acme_first_name" => "Michael",
        "acme_last_name" => "Chen",
        "acme_email" => "m.chen@innovate.io",
        "acme_phone" => "+1-555-234-5678",
        "acme_company" => "Innovate Labs",
        "acme_job_title" => "Product Manager",
        "acme_linkedin" => "https://linkedin.com/in/michaelchen",
        "acme_notes" => "Existing contact in AcmeCRM",
        "acme_source" => "Webinar Attendee"
      },
      {
        "acme_id" => "acme_11111",
        "acme_first_name" => "Emily",
        "acme_last_name" => "Rodriguez",
        "acme_email" => "emily.r@startup.com",
        "acme_phone" => "+1-555-456-7890",
        "acme_company" => "StartupXYZ",
        "acme_job_title" => "Founder",
        "acme_linkedin" => "https://linkedin.com/in/emilyrodriguez",
        "acme_notes" => "Existing contact in AcmeCRM",
        "acme_source" => "Cold Outreach"
      },
      {
        "acme_id" => "acme_22222",
        "acme_first_name" => "David",
        "acme_last_name" => "Kim",
        "acme_email" => "david@enterprise.com",
        "acme_phone" => "+1-555-789-0123",
        "acme_company" => "Enterprise Solutions Inc",
        "acme_job_title" => "VP of Engineering",
        "acme_linkedin" => "https://linkedin.com/in/davidkim",
        "acme_notes" => "Existing contact in AcmeCRM",
        "acme_source" => "Referral"
      },
      {
        "acme_id" => "acme_33333",
        "acme_first_name" => "Lisa",
        "acme_last_name" => "Thompson",
        "acme_email" => "lisa.thompson@consulting.com",
        "acme_phone" => "+1-555-345-6789",
        "acme_company" => "Thompson Consulting",
        "acme_job_title" => "Senior Consultant",
        "acme_linkedin" => "https://linkedin.com/in/lisathompson",
        "acme_notes" => "Existing contact in AcmeCRM", 
        "acme_source" => "LinkedIn"
      }
    ]

    contacts = mock_contacts.first(limit)

    {
      "success" => true,
      "contacts" => contacts,
      "total" => contacts.size
    }
  end

  ##
  # Returns mock single contact data (demo mode)
  ##
  def mock_contact_response(acme_id)
    {
      "success" => true,
      "contact" => {
        "acme_id" => acme_id,
        "acme_first_name" => "Alex",
        "acme_last_name" => "Smith",
        "acme_email" => "alex.smith@example.com",
        "acme_phone" => "+1-555-123-4567",
        "acme_company" => "Example Corp",
        "acme_job_title" => "Marketing Director",
        "acme_linkedin" => "https://linkedin.com/in/alexsmith",
        "acme_notes" => "Mock contact from AcmeCRM",
        "acme_source" => "Linq QR Scan"
      }
    }
  end
end

# Mock data is now hardcoded for demo purposes - no external dependencies needed 