require 'httparty'
module SmsAuthentication
  module SmsProvider
    class AfricasTalkingProvider

      def initialize
        @api_key = SiteSetting.discourse_sms_authentication_at_apikey
        @username = SiteSetting.discourse_sms_authentication_at_username

        case @username
        when 'sandbox'
          @endpoint = 'https://api.sandbox.africastalking.com/version1/messaging'
        else
          @endpoint = 'https://api.africastalking.com/version1/messaging'
        end
      end

      def send_sms(user_phone_number, message)
        if @api_key.nil? || @username.nil?
          raise Exception
        end
        begin
          headers = {
            "apiKey" => @api_key,
            "Content-Type" => 'application/x-www-form-urlencoded',
            "Accept" => 'application/json'
          }

          body = {
            username: @username,
            to: "+#{user_phone_number}",
            message: message.to_s
          }

          response = HTTParty.post(@endpoint, {
            headers: headers,
            body: body
          })

        rescue HTTParty::Error => e
          puts e.message
        rescue StandardError => e
          puts e.message
        end
      end

    end
  end
end
