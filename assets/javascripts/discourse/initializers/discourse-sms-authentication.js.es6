import {withPluginApi} from 'discourse/lib/plugin-api';
import {observes} from 'ember-addons/ember-computed-decorators';
import PreferencesEmail from 'discourse/controllers/preferences/email';
import {propertyEqual} from 'discourse/lib/computed';
import User from "discourse/models/user";
import {ajax} from 'discourse/lib/ajax';
import {userPath} from 'discourse/lib/url';
import InputValidation from 'discourse/models/input-validation';
import computed from 'ember-addons/ember-computed-decorators';
import CreateAccount from 'discourse/controllers/create-account';

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
    newEmailSMS: function(){
      this.set('newEmail', `discourse+${this.get("newPhoneNumber")}@${Discourse.SiteSettings.discourse_sms_authentication_email_domain}`);
    }.observes("newPhoneNumber"),
    unchanged: propertyEqual('newPhoneNumber', 'currentUser.phone_number'),
    newPhoneNumberEmpty: Ember.computed.empty('newPhoneNumber'),
    saveDisabled: Ember.computed.or(
      'saving',
      'newPhoneNumberEmpty',
      'taken',
      'unchanged',
      'invalidPhoneNumber',
    ),
    actions: {
      changeEmail() {
        const self = this;
        this.set('saving', true);

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
  CreateAccount.reopen({
    accountEmailSMS: function() {
      this.set("accountEmail", `discourse+${this.get("accountPhone")}@${Discourse.SiteSettings.discourse_sms_authentication_email_domain}`);
    }.observes("accountPhone"),
    @computed("accountPhone")
    invalidPhoneNumber(accountPhone){
      const re = /^[0-9]*$/;
      return !re.test(accountPhone);
    },
    @computed("invalidPhoneNumber")
    phoneValidation(invalidPhoneNumber){
      if (Ember.isEmpty(this.get("accountPhone"))){
        return InputValidation.create({
	  failed: true
	});
      }
      if (invalidPhoneNumber){
        return InputValidation.create({
	  failed: true,
	  reason: I18n.t("sms_authentication.phone_number.invalid")
	});
      }
      else {
        return InputValidation.create({
	  ok: true,
          reason: I18n.t("sms_authentication.phone_number.valid")
	}); 
      }
    },
    actions: {
      createAccount() {
        const attrs = this.getProperties(
          'accountName',
          'accountEmail',
          'accountPassword',
          'accountUsername',
          'accountPasswordConfirm',
          'accountChallenge',
        );
        const userFields = this.get('userFields');
        const destinationUrl = this.get('authOptions.destination_url');

        if (!Ember.isEmpty(destinationUrl)) {
          $.cookie('destination_url', destinationUrl, {path: '/'});
        }

          attrs.userFields = {};
        // Add the userfields to the data
        if (!Ember.isEmpty(userFields)) {
          userFields.forEach(
            f => (attrs.userFields[f.get('field.id')] = f.get('value')),
          );
        }
	// pass phone_number to back end via user fields
	const phoneField = {
            phone_number: this.get('accountPhone')
	  };
	$.extend(attrs.userFields, phoneField);      
        this.set('formSubmitted', true);
        return Discourse.User.createAccount(attrs).then(
          result => {
            this.set('isDeveloper', false);
            if (result.success) {
              // Trigger the browser's password manager using the hidden static login form:
              const $hidden_login_form = $('#hidden-login-form');
              $hidden_login_form
                .find('input[name=username]')
                .val(attrs.accountUsername);
              $hidden_login_form
                .find('input[name=password]')
                .val(attrs.accountPassword);
              $hidden_login_form
                .find('input[name=redirect]')
                .val(userPath('account-created'));
              $hidden_login_form.submit();
            } else {
              this.flash(
                result.message || I18n.t('create_account.failed'),
                'error',
              );
              if (result.is_developer) {
                this.set('isDeveloper', true);
              }
              if (
                result.errors &&
                result.errors.email &&
                result.errors.email.length > 0 &&
                result.values
              ) {
                this.get('rejectedEmails').pushObject(result.values.email);
              }
              if (
                result.errors &&
                result.errors.password &&
                result.errors.password.length > 0
              ) {
                this.get('rejectedPasswords').pushObject(attrs.accountPassword);
              }
              this.set('formSubmitted', false);
              $.removeCookie('destination_url');
            }
          },
          () => {
            this.set('formSubmitted', false);
            $.removeCookie('destination_url');
            return this.flash(I18n.t('create_account.failed'), 'error');
          },
        );
      },
    },
  });
}

export default {
  name: 'discourse-sms-authentication',

  initialize() {
    withPluginApi('0.8.24', initialize_discourse_sms_authentication);
  },
};
