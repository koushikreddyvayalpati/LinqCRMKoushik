# frozen_string_literal: true

##
# API::V1::AuthController handles authentication and JWT token generation
# For demo purposes, provides simple token generation without real user authentication
# In production, this would integrate with your user authentication system
##
class Api::V1::AuthController < ApplicationController
  # No need to skip CSRF in API mode - it's already disabled

  ##
  # POST /api/v1/auth/login
  # Generates a JWT token for API access (demo implementation)
  ##
  def login
    begin
      # In demo mode, accept any valid email/user_id combination
      user_params = params.permit(:email, :user_id, :name, :company)
      
      unless user_params[:email].present?
        return render_error("Email is required", :bad_request)
      end

      # Validate email format
      unless valid_email?(user_params[:email])
        return render_error("Invalid email format", :bad_request)
      end

      # Create JWT payload
      payload = {
        user_id: user_params[:user_id] || SecureRandom.uuid,
        email: user_params[:email],
        name: user_params[:name] || "Demo User",
        company: user_params[:company] || "Demo Company",
        iat: Time.current.to_i,
        aud: "linq-crm-integration"
      }

      # Generate token
      token = JwtService.encode(payload)

      Rails.logger.info("Generated JWT token for user: #{user_params[:email]}")

      render json: {
        success: true,
        message: "Authentication successful",
        token: token,
        expires_at: 24.hours.from_now.iso8601,
        user: {
          id: payload[:user_id],
          email: payload[:email],
          name: payload[:name],
          company: payload[:company]
        }
      }, status: :ok

    rescue => e
      Rails.logger.error("Error in auth#login: #{e.message}")
      render_error("Authentication failed", :internal_server_error)
    end
  end

  ##
  # POST /api/v1/auth/validate
  # Validates a JWT token and returns user information
  ##
  def validate
    begin
      token = extract_token_from_header

      unless token
        return render_error("Missing authorization token", :unauthorized)
      end

      payload = JwtService.decode(token)

      render json: {
        success: true,
        valid: true,
        user: {
          id: payload[:user_id],
          email: payload[:email],
          name: payload[:name],
          company: payload[:company]
        },
        expires_at: Time.at(payload[:exp]).iso8601
      }, status: :ok

    rescue JWT::ExpiredSignature
      render_error("Token has expired", :unauthorized)
    rescue JWT::DecodeError => e
      render_error("Invalid token: #{e.message}", :unauthorized)
    rescue => e
      Rails.logger.error("Error in auth#validate: #{e.message}")
      render_error("Token validation failed", :internal_server_error)
    end
  end

  private

  ##
  # Validates email format using URI regex
  ##
  def valid_email?(email)
    email.match?(URI::MailTo::EMAIL_REGEXP)
  end

  ##
  # Extracts JWT token from Authorization header
  ##
  def extract_token_from_header
    auth_header = request.headers["Authorization"]
    return nil unless auth_header&.start_with?("Bearer ")
    
    auth_header.split(" ").last
  end

  ##
  # Renders error response with consistent format
  ##
  def render_error(message, status)
    render json: {
      success: false,
      error: message,
      status: Rack::Utils::SYMBOL_TO_STATUS_CODE[status]
    }, status: status
  end
end
