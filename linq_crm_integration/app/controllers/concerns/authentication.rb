# frozen_string_literal: true

##
# Authentication concern for controllers
# Provides JWT-based authentication with proper error handling
##
module Authentication
  extend ActiveSupport::Concern

  included do
    before_action :authenticate_request
    attr_reader :current_user_payload
  end

  private

  ##
  # Authenticates the request using JWT token from Authorization header
  # Sets @current_user_payload if authentication is successful
  ##
  def authenticate_request
    token = extract_token_from_header
    
    unless token
      render_unauthorized("Missing authorization token")
      return
    end

    begin
      @current_user_payload = JwtService.decode(token)
    rescue JWT::ExpiredSignature
      render_unauthorized("Token has expired")
    rescue JWT::DecodeError => e
      render_unauthorized("Invalid token: #{e.message}")
    end
  end

  ##
  # Extracts JWT token from Authorization header
  # Expected format: "Bearer <token>"
  # @return [String, nil] The token or nil if not found
  ##
  def extract_token_from_header
    auth_header = request.headers["Authorization"]
    return nil unless auth_header&.start_with?("Bearer ")
    
    auth_header.split(" ").last
  end

  ##
  # Renders unauthorized response with consistent format
  # @param message [String] Error message to return
  ##
  def render_unauthorized(message = "Unauthorized")
    render json: {
      error: "Authentication failed",
      message: message,
      status: 401
    }, status: :unauthorized
  end

  ##
  # Skips authentication for specific actions
  # Usage: skip_authentication only: [:public_action]
  ##
  def skip_authentication(**options)
    skip_before_action :authenticate_request, **options
  end
end 