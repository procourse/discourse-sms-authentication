import {withPluginApi} from 'discourse/lib/plugin-api';
import {observes} from 'ember-addons/ember-computed-decorators';
import PreferencesEmail from 'discourse/controllers/preferences/email';
import {propertyEqual} from 'discourse/lib/computed';
import User from 'discourse/models/user';
import {ajax} from 'discourse/lib/ajax';
import {userPath} from 'discourse/lib/url';
import InputValidation from "discourse/models/input-validation";
import computed from "ember-addons/ember-computed-decorators";

function initialize_discourse_sms_authentication(api) {
  User.reopen({
    changeEmail(email, phone_number) {
      return ajax(userPath(`${this.get('username_lower')}/preferences/email`), {
        type: 'PUT',
        data: {email, phone_number},
      });
    },
  });
  PreferencesEmail.reopen({
    newPhoneNumber: function() {
      return this.get('currentUser.phone_number') || null;
    }.property(),
    unchanged: propertyEqual('newPhoneNumber', 'currentUser.phone_number'),
    newPhoneNumberEmpty: Ember.computed.empty('newPhoneNumber'),
    saveDisabled: Ember.computed.or(
      'saving',
      'newPhoneNumberEmpty',
      'taken',
      'unchanged',
      'invalidPhoneNumber',
    ),
    @computed("newPhoneNumber")
    invalidPhoneNumber(newPhoneNumber){
      const re = /^[0-9]*$/;
      return !re.test(newPhoneNumber);
    },
    @computed("invalidPhoneNumber")
    phoneNumberValidation(invalidPhoneNumber){
      if (invalidPhoneNumber){
        return InputValidation.create({
	  failed: true,
          reason: I18n.t("sms_authentication.phone_number.invalid")
	});
      }
    },
    actions: {
      changeEmail() {
        const self = this;
        this.set('saving', true);

        this.set('newEmail', `discourse+${this.get('newPhoneNumber')}@tala.co`);
        this.changePhoneNumber(this.get('model'));
        return this.get('model')
          .changeEmail(this.get('newEmail'), this.get('newPhoneNumber'))
          .then(
            () => self.set('success', true),
            e => {
              self.setProperties({error: true, saving: false});
              if (
                e.jqXHR.responseJSON &&
                e.jqXHR.responseJSON.errors &&
                e.jqXHR.responseJSON.errors[0]
              ) {
                self.set('errorMessage', e.jqXHR.responseJSON.errors[0]);
              } else {
                self.set('errorMessage', I18n.t('user.change_email.error'));
              }
            },
          );
      },
    },
    changePhoneNumber(obj) {
      obj.set('phone_number', this.get('newPhoneNumber'));
    },
  });
}

export default {
  name: 'discourse-sms-authentication',

  initialize() {
    withPluginApi('0.8.24', initialize_discourse_sms_authentication);
  },
};
