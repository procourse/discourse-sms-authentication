# name: discourse-sms-authentication
# about: Enable Discourse to use SMS for authentication
# version: 0.1
# author: ProCourse procourse.co
# license: https://github.com/procourse/discourse-sms-authentication/blob/master/LICENSE
# url: https://github.com/procourse/discourse-sms-authentication

enabled_site_setting :discourse_sms_authentication_enabled

gem 'phonelib', '0.6.29'

register_asset 'stylesheets/discourse-sms-authentication.scss'
DiscoursePluginRegistry.serialized_current_user_fields << 'phone_number'

after_initialize do
  # Turn off sign in by email
  SiteSetting.enable_local_logins_via_email = false

  User.register_custom_field_type('phone_number', :text)
  register_editable_user_custom_field :phone_number

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
      end
    end
    prepend SmsAuthentication
  end

  require_dependency 'users_controller'
  class ::UsersController
      after_action :add_phone_number, only: [:create]
      def add_phone_number

        user = User.find_by(username: params[:username]) 

        if user
          user.custom_fields['phone_number'] = params[:user_fields][:phone_number]
          user.save!
        end
      end
      module SmsAuthentication
        def update_activation_email
          original = super

          if params[:username].present?
            user = User.find_by_username_or_email(params[:username])
            raise Discourse::InvalidAccess.new unless user.present?
            raise Discourse::InvalidAccess.new unless user.confirm_password?(params[:password])
          elsif user_key = session[SessionController::ACTIVATE_USER_KEY]
            user = User.where(id: user_key.to_i).first
          end

          if user
            user.custom_fields['phone_number'] = params[:phone_number]
            user.save!
          end
          original
        end
      end
      prepend SmsAuthentication
  end
end
