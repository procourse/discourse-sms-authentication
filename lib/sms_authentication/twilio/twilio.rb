require 'twilio-ruby'
module SmsAuthentication
  module SmsProvider
    class Twilio

      def initialize
        account_sid = SiteSetting.discourse_sms_authentication_account_sid
        auth_token = SiteSetting.discourse_sms_authentication_authtoken

        @client = Twilio::REST::Client.new account_sid, auth_token
      end

      def send_sms(user_phone_number, message)
        @client.api.account.messages.create(
          from: "+#{SiteSetting.discourse_sms_authentication_send_phone}",
          to: "+#{user_phone_number}",
          body: message.to_s
        )
      rescue
        'Error'
      end

    end
  end
end
