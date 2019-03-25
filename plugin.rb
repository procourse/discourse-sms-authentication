# name: discourse-sms-authentication
# about: Enable Discourse to use SMS for authentication
# version: 0.1
# author: ProCourse procourse.co
# license: https://github.com/procourse/discourse-sms-authentication/blob/master/LICENSE
# url: https://github.com/procourse/discourse-sms-authentication

enabled_site_setting :discourse_sms_authentication_enabled

gem 'phonelib', '0.6.29'
gem 'twilio-ruby', '5.21.2'

register_asset 'stylesheets/discourse-sms-authentication.scss'
DiscoursePluginRegistry.serialized_current_user_fields << 'phone_number'

load File.expand_path('../lib/sms_authentication/sms_provider.rb', __FILE__)

after_initialize do
  # Turn off sign in by email
  SiteSetting.enable_local_logins_via_email = false

  # Add phone number to user model and serializer
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

        user = User.find(current_user.id)

        RateLimiter.new(user, "change-phone-hr-#{request.remote_ip}", 6, 1.hour).performed!
        RateLimiter.new(user, "change-phone-min-#{request.remote_ip}", 3, 1.minute).performed!

        if params[:phone_number]
          user.custom_fields['phone_number'] = params[:phone_number]
          user.save!
          DiscourseEvent.trigger(:sms_user_updated, user)
        end
        original
      end
    end
    prepend SmsAuthentication
  end

  # Add phone number save on user creation
  require_dependency 'users_controller'
  class ::UsersController
      after_action :add_phone_number, only: [:create]
      after_action :update_phone_number, only: [:update_activation_email]
      def add_phone_number

        user = User.find_by(username: params[:username]) 

        if user
          user.custom_fields['phone_number'] = params[:user_fields][:phone_number]
          user.save!
        end
        DiscourseEvent.trigger(:sms_user_created, user)
      end
      def update_phone_number

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
        DiscourseEvent.trigger(:sms_user_created, user)
      end
  end

  # Send SMS Messages on Discourse Events
  DiscourseEvent.on(:sms_user_created) do |user|
    # Build message content with email token
    activation_url = "#{Discourse.base_protocol}://#{Discourse.current_hostname}/u/activate-account/#{user.email_tokens.last.token}"
    message = "Activate your #{SiteSetting.title} account: #{activation_url}"

    # Send SMS using provider
    sms = SmsAuthentication::SmsProvider::Provider.new
    sms.send_sms(user.custom_fields['phone_number'], message)
  end
  DiscourseEvent.on(:sms_user_updated) do |user|
    # Build message content with email token
    activation_url = "#{Discourse.base_protocol}://#{Discourse.current_hostname}/u/authorize-email/#{user.email_tokens.last.token}"
    message = "#{I18n.t('sms_authentication.sms_messages.activation', title: SiteSetting.title)}#{activation_url}"

    # Send SMS using provider
    sms = SmsAuthentication::SmsProvider::Provider.new
    sms.send_sms(user.custom_fields['phone_number'], message)
  end
  
  DiscourseEvent.on(:post_notification_alert) do |user, payload|
    # Build message content with notification info
    case payload[:notification_type]
    when 1
      type = I18n.t('sms_authentication.sms_messages.mention')
    when 2
      type = I18n.t('sms_authentication.sms_messages.reply')
    when 6
      type = I18n.t('sms_authentication.sms_messages.pm')
    else
      return
    end
    url = "#{Discourse.base_protocol}://#{Discourse.current_hostname}#{payload[:post_url]}"
    message = "#{I18n.t('sms_authentication.sms_messages.notification', type: type, user: payload[:username])}#{url}"

    # Send SMS using provider
    sms = SmsAuthentication::SmsProvider::Provider.new
    sms.send_sms(user.custom_fields['phone_number'], message)
  end

  
end
