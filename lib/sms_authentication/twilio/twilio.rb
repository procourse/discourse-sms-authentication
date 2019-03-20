require 'twilio-ruby'
module SmsAuthentication
  module SmsProvider
    class TwilioProvider

      def initialize
        account_sid = SiteSetting.discourse_sms_authentication_account_sid
        auth_token = SiteSetting.discourse_sms_authentication_authtoken

        @client = Twilio::REST::Client.new(account_sid, auth_token)
      end

      def send_sms(user_phone_number, message)
        if SiteSetting.discourse_sms_authentication_send_phone.nil?
          raise Exception
        end
        begin
          response = @client.messages.create(
            from: "+#{SiteSetting.discourse_sms_authentication_send_phone}",
            to: "+#{user_phone_number}",
            body: message.to_s
          )
        rescue Twilio::REST::TwilioError => e
          puts e.message
        end
      end

    end
  end
end
