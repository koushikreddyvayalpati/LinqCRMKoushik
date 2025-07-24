# frozen_string_literal: true

##
# JWT Service handles encoding and decoding of JSON Web Tokens
# Used for API authentication with proper error handling
##
class JwtService
  # Use environment variable or fallback to default for development
  SECRET_KEY = Rails.application.credentials.secret_key_base || "development_secret"
  ALGORITHM = "HS256"
  
  # Token expires in 24 hours by default
  DEFAULT_EXPIRATION = 24.hours.from_now

  class << self
    ##
    # Encodes a payload into a JWT token
    # @param payload [Hash] The data to encode
    # @param expiration [Time] When the token should expire
    # @return [String] The JWT token
    ##
    def encode(payload, expiration = DEFAULT_EXPIRATION)
      payload[:exp] = expiration.to_i
      JWT.encode(payload, SECRET_KEY, ALGORITHM)
    end

    ##
    # Decodes a JWT token and returns the payload
    # @param token [String] The JWT token to decode
    # @return [Hash] The decoded payload
    # @raise [JWT::ExpiredSignature] If token has expired
    # @raise [JWT::DecodeError] If token is invalid
    ##
    def decode(token)
      decoded = JWT.decode(token, SECRET_KEY, true, { algorithm: ALGORITHM })
      decoded.first.with_indifferent_access
    rescue JWT::ExpiredSignature
      raise JWT::ExpiredSignature, "Token has expired"
    rescue JWT::DecodeError => e
      raise JWT::DecodeError, "Invalid token: #{e.message}"
    end

    ##
    # Validates if a token is still valid
    # @param token [String] The JWT token to validate
    # @return [Boolean] True if valid, false otherwise
    ##
    def valid?(token)
      decode(token)
      true
    rescue JWT::ExpiredSignature, JWT::DecodeError
      false
    end
  end
end 