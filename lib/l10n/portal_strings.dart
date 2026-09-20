import 'portal_locale.dart';

/// All customer-portal user-facing text, English + Swahili. `t(key)` reads
/// the current PortalLocale.instance.language; `t(key, {'0': value})`
/// substitutes `{0}`, `{1}`, ... placeholders (word order sometimes
/// differs between the two languages, so each entry places its own
/// placeholder rather than sharing one template).
class PortalStrings {
  PortalStrings._();

  static String t(String key, [Map<String, String>? args]) {
    final lang = PortalLocale.instance.language.value;
    final entry = _map[key];
    var text = entry?[lang] ?? entry?['en'] ?? key;
    if (args != null) {
      args.forEach((k, v) => text = text.replaceAll('{$k}', v));
    }
    return text;
  }

  static const Map<String, Map<String, String>> _map = {
    // Login
    'customer_login': {'en': 'Customer Login', 'sw': 'Kuingia kwa Mteja'},
    'view_history': {
      'en': 'View your contract & payment history',
      'sw': 'Ona historia ya mkataba na malipo yako',
    },
    'business_code': {'en': 'Business Code', 'sw': 'Namba ya Biashara'},
    'phone_number': {'en': 'Phone Number', 'sw': 'Namba ya Simu'},
    'password': {'en': 'Password', 'sw': 'Password'},
    'required': {'en': 'Required', 'sw': 'Inahitajika'},
    'login': {'en': 'Login', 'sw': 'Ingia'},
    'forgot_password_q': {
      'en': 'Forgot password?',
      'sw': 'Umesahau password?',
    },
    'no_account_register': {
      'en': "Don't have an account? Register",
      'sw': 'Huna akaunti? Jisajili',
    },

    // Register
    'register_title': {'en': 'Register', 'sw': 'Jisajili'},
    'register_intro': {
      'en': 'Register with the phone number on your contract. '
          "We'll text you a code to confirm it's you.",
      'sw': 'Jisajili kwa namba ya simu iliyopo kwenye mkataba wako. '
          'Tutakutumia namba ya uthibitisho kwa SMS.',
    },
    'confirm_password': {'en': 'Confirm Password', 'sw': 'Rudia Password'},
    'min_6_chars': {
      'en': 'At least 6 characters',
      'sw': 'Angalau herufi 6',
    },
    'send_code': {'en': 'Send Code', 'sw': 'Tuma Namba'},
    'passwords_no_match': {
      'en': 'Passwords do not match',
      'sw': 'Password hazifanani',
    },

    // Verify registration
    'verify_phone': {'en': 'Verify Phone', 'sw': 'Thibitisha Namba'},
    'verify_intro': {
      'en': 'If {0} is eligible, we sent a 6-digit code by SMS. '
          'Enter it below to activate your account.',
      'sw': 'Kama {0} inastahili, tumekutumia namba ya tarakimu 6 kwa SMS. '
          'Iweke hapa chini kuwasha akaunti yako.',
    },
    'verify': {'en': 'Verify', 'sw': 'Thibitisha'},

    // Forgot password
    'forgot_password_title': {
      'en': 'Forgot Password',
      'sw': 'Umesahau Password',
    },
    'forgot_intro': {
      'en':
          "We'll text a code to confirm it's you, then let you set a new password.",
      'sw':
          'Tutakutumia namba ya uthibitisho kwa SMS, kisha uweke password mpya.',
    },

    // Reset password
    'reset_password_title': {
      'en': 'Reset Password',
      'sw': 'Badilisha Password',
    },
    'reset_intro': {
      'en': 'Enter the code sent to {0} and your new password.',
      'sw': 'Weka namba iliyotumwa kwa {0} na password yako mpya.',
    },
    'otp': {'en': 'OTP', 'sw': 'OTP'},
    'new_password': {'en': 'New Password', 'sw': 'Password Mpya'},
    'confirm_new_password': {
      'en': 'Confirm New Password',
      'sw': 'Rudia Password Mpya',
    },
    'reset_password_btn': {
      'en': 'Reset Password',
      'sw': 'Badilisha Password',
    },
    'password_reset_success': {
      'en': 'Password reset. Please log in.',
      'sw': 'Password imebadilishwa. Tafadhali ingia.',
    },

    // Dashboard shell / bottom nav
    'dashboard': {'en': 'Dashboard', 'sw': 'Dashibodi'},
    'mikataba': {'en': 'Contracts', 'sw': 'Mikataba'},
    'malipo': {'en': 'Payments', 'sw': 'Malipo'},
    'taarifa': {'en': 'Statement', 'sw': 'Taarifa'},
    'account': {'en': 'Account', 'sw': 'Akaunti'},
    'total_owed_label': {
      'en': 'Your total balance right now',
      'sw': 'Deni lako lote kwa sasa',
    },
    'fully_paid': {
      'en': "You've paid off everything",
      'sw': 'Umeshalipa deni lako lote',
    },
    'phone_number_colon': {
      'en': 'Phone number: {0}',
      'sw': 'Namba ya simu: {0}',
    },
    'your_contracts': {'en': 'Your Contracts', 'sw': 'Mikataba Yako'},
    'no_contracts': {
      'en': 'No contracts found for this phone number.',
      'sw': 'Hakuna mkataba uliopatikana kwa namba hii ya simu.',
    },
    'no_contract_for_payments': {
      'en': 'No contract to show payments for.',
      'sw': 'Hakuna mkataba wa kuonyesha malipo yake.',
    },
    'no_contract_for_statement': {
      'en': 'No contract to show a statement for.',
      'sw': 'Hakuna mkataba wa kuonyesha taarifa yake.',
    },
    'contract_label': {'en': 'Contract', 'sw': 'Mkataba'},
    'balance_label': {'en': 'balance', 'sw': 'salio'},
    'percent_paid': {'en': '{0}% paid', 'sw': '{0}% imelipwa'},
    'day_of_contract': {'en': 'Day of contract', 'sw': 'Siku ya mkataba'},
    'days_overdue': {'en': 'Days overdue', 'sw': 'Amepitisha siku'},
    'overdue_contracts_count': {
      'en': 'Overdue contracts',
      'sw': 'Mikataba iliyochelewa',
    },
    'current_contract': {'en': 'Current contract', 'sw': 'Mkataba wa sasa'},
    'recent_payments': {
      'en': 'Recent payments',
      'sw': 'Malipo ya hivi karibuni'
    },
    'none': {'en': 'None', 'sw': 'Hakuna'},
    'n_days': {'en': '{0} days', 'sw': 'siku {0}'},
    'paid_so_far': {'en': 'Paid so far', 'sw': 'Amelipa hadi sasa'},
    'balance_remaining': {
      'en': 'Balance remaining',
      'sw': 'Salio linalobaki',
    },
    'owed_today': {'en': 'Owed as of today', 'sw': 'Anadaiwa hadi leo'},
    'daily_rate_label': {
      'en': 'Daily rate',
      'sw': 'Kiwango cha kila siku',
    },
    'status_terminated': {'en': 'Terminated', 'sw': 'Umesitishwa'},
    'status_completed': {'en': 'Fully paid', 'sw': 'Imelipwa kamili'},
    'status_on_track': {'en': 'On track', 'sw': 'Inaendelea vizuri'},
    'status_behind': {'en': 'Behind', 'sw': 'Umechelewa'},
    'status_overdue': {'en': 'Very behind', 'sw': 'Umechelewa sana'},
    'change_password_tile': {
      'en': 'Change Password',
      'sw': 'Badilisha Password',
    },
    'logout': {'en': 'Logout', 'sw': 'Toka'},

    // Contract detail
    'terminated_banner': {
      'en': 'This contract has been terminated{0}',
      'sw': 'Mkataba huu umesitishwa{0}',
    },
    'payments_menu': {'en': 'Payments', 'sw': 'Malipo'},
    'statement_menu': {'en': 'Statement', 'sw': 'Taarifa (Statement)'},
    'whatsapp_menu': {
      'en': 'WhatsApp Number',
      'sw': 'Namba ya WhatsApp',
    },
    'contract_cost': {'en': 'Contract cost', 'sw': 'Gharama ya mkataba'},
    'amount_disbursed': {
      'en': 'Amount disbursed',
      'sw': 'Kiasi kilichotolewa',
    },
    'debt_to_date': {'en': 'Debt to date', 'sw': 'Deni hadi sasa'},
    'debt_to_date_sub': {
      'en': '{0}/day × {1} days',
      'sw': '{0}/siku × {1} siku',
    },
    'total_paid': {'en': 'Total paid', 'sw': 'Jumla iliyolipwa'},
    'n_payments': {'en': '{0} payments', 'sw': '{0} malipo'},
    'overdue_debt': {
      'en': 'Overdue debt',
      'sw': 'Deni lililochelewa',
    },
    'overdue_days': {
      'en': '{0} days overdue',
      'sw': 'Amechelewa siku {0}',
    },
    'nothing_overdue': {
      'en': 'Nothing overdue',
      'sw': 'Hakuna linalochelewa',
    },
    'contract_balance': {
      'en': 'Contract balance',
      'sw': 'Salio la mkataba',
    },
    'fully_paid_small': {'en': 'Paid', 'sw': 'Imekamilika'},
    'remaining': {'en': 'Remaining', 'sw': 'Inabaki'},
    'contract_details_header': {
      'en': 'CONTRACT DETAILS',
      'sw': 'MAELEZO YA MKATABA',
    },
    'starts': {'en': 'Starts', 'sw': 'Kuanza'},
    'ends': {'en': 'Ends', 'sw': 'Kumalizika'},
    'duration': {'en': 'Duration', 'sw': 'Muda'},
    'n_months': {'en': '{0} months', 'sw': 'miezi {0}'},
    'guarantor_1': {'en': 'Guarantor 1', 'sw': 'Mdhamini 1'},
    'guarantor_2': {'en': 'Guarantor 2', 'sw': 'Mdhamini 2'},
    'whatsapp_number_field': {
      'en': 'WhatsApp Number',
      'sw': 'Namba ya WhatsApp',
    },
    'not_set': {'en': 'Not set', 'sw': 'Haijawekwa'},
    'plate_number': {'en': 'Plate Number', 'sw': 'Namba ya Plate'},
    'chassis': {'en': 'Chassis', 'sw': 'Chassis'},
    'insurance': {'en': 'Insurance', 'sw': 'Bima'},
    'insurance_expiry': {
      'en': 'Insurance Expiry',
      'sw': 'Bima inaisha',
    },
    'payment_progress': {
      'en': 'Payment progress',
      'sw': 'Maendeleo ya malipo',
    },
    'today_label': {'en': 'Today {0}', 'sw': 'Leo {0}'},
    'undated_note': {
      'en':
          'The total includes TSH {0} from old records without an exact date.',
      'sw':
          'Jumla ya malipo inajumuisha TSH {0} kutoka kwenye rekodi za zamani zisizo na tarehe kamili.',
    },
    'payments_header': {'en': 'Payments', 'sw': 'Malipo'},
    'no_payments_yet': {
      'en': 'No payments recorded yet.',
      'sw': 'Hakuna malipo yaliyorekodiwa bado.',
    },
    'show_all_payments': {
      'en': 'Show all payments ({0} more)',
      'sw': 'Onyesha malipo yote ({0} zaidi ya awali)',
    },
    'whatsapp_dialog_title': {
      'en': 'WhatsApp Number',
      'sw': 'Namba ya WhatsApp',
    },
    'whatsapp_dialog_body': {
      'en': 'If you use a different number for WhatsApp, enter it here. '
          "Leave blank if it's the same as your SMS number.",
      'sw': 'Kama unatumia namba tofauti kwa WhatsApp, iweke hapa. '
          'Acha wazi kama ni namba ile ile unayotumia kwa SMS.',
    },
    'cancel': {'en': 'Cancel', 'sw': 'Ghairi'},
    'save': {'en': 'Save', 'sw': 'Hifadhi'},
    'whatsapp_saved': {
      'en': 'WhatsApp number saved',
      'sw': 'Namba ya WhatsApp imehifadhiwa',
    },

    // Statement
    'to_label': {'en': 'to', 'sw': 'hadi'},
    'no_data_for_range': {
      'en': 'No data for this period.',
      'sw': 'Hakuna data kwa kipindi hiki.',
    },
    'share_pdf': {'en': 'Share PDF', 'sw': 'Shiriki PDF'},
    'credit': {'en': 'Credit', 'sw': 'Kinachodaiwa'},
    'debit': {'en': 'Debit', 'sw': 'Alicholipa'},
    'balance': {'en': 'Balance', 'sw': 'Salio'},
    'opening_balance': {'en': 'Opening Balance', 'sw': 'Salio la Mwanzo'},
    'closing_balance': {'en': 'Closing Balance', 'sw': 'Salio la Mwisho'},

    // Change password
    'change_password_title': {
      'en': 'Change Password',
      'sw': 'Badilisha Password',
    },
    'current_password': {
      'en': 'Current Password',
      'sw': 'Password ya Sasa',
    },
    'new_password_field': {
      'en': 'New Password',
      'sw': 'Password Mpya',
    },
    'confirm_new_password_field': {
      'en': 'Confirm New Password',
      'sw': 'Rudia Password Mpya',
    },
    'enter_current_password': {
      'en': 'Enter your current password',
      'sw': 'Weka password ya sasa',
    },
    'new_password_min': {
      'en': 'Password must be at least 6 characters',
      'sw': 'Password iwe na herufi 6 au zaidi',
    },
    'confirm_new_password_required': {
      'en': 'Confirm your new password',
      'sw': 'Rudia password mpya',
    },
    'new_passwords_no_match': {
      'en': 'New passwords do not match',
      'sw': 'Password mpya hazifanani',
    },
    'password_changed': {
      'en': 'Password changed',
      'sw': 'Password imebadilishwa',
    },
  };
}
