require_relative 'twilio/twilio.rb'
require_relative 'africas_talking/africas_talking.rb'
require_relative 'braze/braze.rb'

module SmsAuthentication
  module SmsProvider
    class Provider
      def initialize(options = {})
        @options = options

        provider_setting = SiteSetting.discourse_sms_authentication_provider

        case provider_setting
        when "Twilio"
          @provider = SmsAuthentication::SmsProvider::TwilioProvider.new
        when "Africa's Talking"
          @provider = SmsAuthentication::SmsProvider::AfricasTalkingProvider.new
        when "Braze"
          @provider = SmsAuthentication::SmsProvider::AfricasTalkingProvider.new
        end

      end

      def send_sms(user_phone_number, message)
        @provider.send_sms(user_phone_number, message)
      end
    end
  end
end
