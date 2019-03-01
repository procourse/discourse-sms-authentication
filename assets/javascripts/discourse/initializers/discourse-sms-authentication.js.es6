import { withPluginApi } from "discourse/lib/plugin-api";
import PreferencesAccount from "discourse/controllers/preferences/account";
import { observes } from "ember-addons/ember-computed-decorators";

function initialize_discourse_sms_authentication(api) {
PreferencesAccount.reopen({
        saveAttrNames: ["name", "title", "custom_fields"],
	setPhoneNumber(obj) {
          obj.set("phone_number", this.get("model.custom_fields.phone_number"));
        },

	_updatePhoneNumber: function() {
	    if (!this.siteSettings.discourse_sms_authentication_enabled) return;
            if (this.get("saved")) {
	        this.setPhoneNumber(this.get("model"));
	    }
	}.observes("saved")
});
}

export default {
  name: "discourse-sms-authentication",

  initialize() {
    withPluginApi("0.8.24", initialize_discourse_sms_authentication);
  }
};
