# name: discourse-sms-authentication
# about: Enable Discourse to use SMS for authentication
# version: 0.1
# author: ProCourse procourse.co
# license: https://github.com/procourse/discourse-sms-authentication/blob/master/LICENSE
# url: https://github.com/procourse/discourse-sms-authentication

enabled_site_setting :discourse_sms_authentication_enabled

register_asset 'stylesheets/discourse-sms-authentication.scss'
DiscoursePluginRegistry.serialized_current_user_fields << 'phone_number'

after_initialize do
  User.register_custom_field_type('phone_number', :text)

  require_dependency 'user'
  class ::User
    def phone_number
      self.custom_fields['phone_number']
    end
  end

  require_dependency 'current_user_serializer'
  class ::CurrentUserSerializer
    attributes :phone_number

    def phone_number
      object.phone_number
    end
  end

  # Add phone number save to email controller
  require_dependency 'users_email_controller'
  require_dependency 'rate_limiter'
  class ::UsersEmailController
    module SmsAuthentication
      def update
        original = super

        params.require(:phone_number)
        user = User.find(current_user.id)

        RateLimiter.new(user, "change-phone-hr-#{request.remote_ip}", 6, 1.hour).performed!
        RateLimiter.new(user, "change-phone-min-#{request.remote_ip}", 3, 1.minute).performed!
        user.custom_fields['phone_number'] = params[:phone_number]
        user.save!

        original
      rescue RateLimiter::LimitExceeded
        render_json_error(I18n.t('rate_limiter.slow_down'))
      end
    end
    prepend SmsAuthentication
  end

end
