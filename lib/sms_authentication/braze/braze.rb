require 'net/http'

module SmsAuthentication
  module SmsProvider
    class BrazeProvider
      def send_sms(user_phone_number, message)
        api_key = SiteSetting.discourse_sms_authentication_braze_api_key
        campaign_id = SiteSetting.discourse_sms_authentication_braze_campaign_id
        braze_url = SiteSetting.discourse_sms_authentication_braze_url
        message_body = message.to_s
        ph_number = user_phone_number.to_s

        begin
          http = Net::HTTP.new(`#{braze_url}/campaigns/trigger/send`)
          request = Net::HTTP::Post.new(url)
          request["Content-Type"] = 'application/json'
          request.body = {
            'api_key' => api_key,
            'campaign_id' => campaign_id,
            'trigger_properties' => {
              'message_body' => message_body
            },
            'recipients': [
              {
                'external_user_id' => external_user_id
              }
            ]
          }.to_json

          response = http.request(request)

        rescue => e
          puts e.message
        end
      end

    end
  end
end
