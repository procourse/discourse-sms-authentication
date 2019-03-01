# name: discourse-sms-authentication 
# about: Enable Discourse to use SMS for authentication 
# version: 0.1
# author: ProCourse procourse.co
# license: https://github.com/procourse/discourse-sms-authentication/blob/master/LICENSE
# url: https://github.com/procourse/discourse-sms-authentication

enabled_site_setting :discourse_sms_authentication_enabled

register_asset 'stylesheets/discourse-sms-authentication.scss'

DiscoursePluginRegistry.serialized_current_user_fields << "phone_number"

after_initialize do
  User.register_custom_field_type("phone_number", :text)
  register_editable_user_custom_field :phone_number

  require_dependency "user"
  if SiteSetting.discourse_sms_authentication_enabled then
    add_to_serializer(:user, :phone_number) {
      if scope.user
        object.custom_fields["phone_number"]
      end
    }
  end
end
