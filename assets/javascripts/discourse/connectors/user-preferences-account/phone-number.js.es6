export default {

    shouldRender({ model }, component) {
      return component.siteSettings.discourse_sms_authentication_enabled;
    },
  
    setupComponent({ model }, component) {
      model.set("custom_fields.phone_number", model.get("phone_number"));
    }
  
};
