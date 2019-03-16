module SmsAuthentication
  module SmsProvider
    class Provider
      def initialize(options = {})
        @options = options

        provider_setting = SiteSetting.discourse_sms_authentication_provider

        case provider_setting
        when "Twilio"
          @provider = SmsAuthentication::SmsProvider::Twilio.new
        end

      end

      def send_sms(user_phone_number, message)
        @provider.send_sms(user_phone_number, message)
      end
    end
  end
end
