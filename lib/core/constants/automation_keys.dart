import 'package:flutter/material.dart';

class AutomationKeys {
  // Auth Screen
  static const Key loginEmailField = ValueKey('login_email_field');
  static const Key loginPasswordField = ValueKey('login_password_field');
  static const Key loginSubmitButton = ValueKey('login_submit_button');
  static const Key loginToRegisterLink = ValueKey('login_to_register_link');

  // Register Screen
  static const Key registerNameField = ValueKey('register_name_field');
  static const Key registerEmailField = ValueKey('register_email_field');
  static const Key registerPasswordField = ValueKey('register_password_field');
  static const Key registerSubmitButton = ValueKey('register_submit_button');
  static const Key registerToLoginLink = ValueKey('register_to_login_link');

  // KYC Screen
  static const Key kycIdNumberField = ValueKey('kyc_id_number_field');
  static const Key kycIdCardPicker = ValueKey('kyc_id_card_picker');
  static const Key kycSelfiePicker = ValueKey('kyc_selfie_picker');
  static const Key kycSubmitButton = ValueKey('kyc_submit_button');

  // Profile Screen
  static const Key profileLogoutButton = ValueKey('profile_logout_button');
  static const Key profileKycMenu = ValueKey('profile_kyc_menu');
}
