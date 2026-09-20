/// Contract Rules / Message Templates -- the same tenant-wide settings web
/// edits at My Subscription -> Contract Rules (late fee, auto-termination,
/// SMS/WhatsApp channel, message wording). Numeric fields stay as strings
/// since they're just bound to text fields and re-sent verbatim; the
/// backend (api/Contract_settings.php) does the actual validation.
class ContractSettings {
  final String penaltyPerDay;
  final String penaltyGraceDays;
  final String terminationGraceDays;
  final bool reminderSmsEnabled;
  final String stage2Days;
  final String stage3Days;
  final String repossessionFee;
  final bool terminationSmsEnabled;
  final bool confirmationSmsEnabled;
  final bool paymentSmsEnabled;
  final String whatsappPhone;

  /// 'sms' | 'whatsapp' | 'both'.
  final String messageChannel;

  /// Whether the tenant's MoSmS account has an approved custom_message
  /// WhatsApp template -- 'whatsapp'/'both' only actually send once true.
  final bool waReady;

  final Map<String, String> templates;

  const ContractSettings({
    required this.penaltyPerDay,
    required this.penaltyGraceDays,
    required this.terminationGraceDays,
    required this.reminderSmsEnabled,
    required this.stage2Days,
    required this.stage3Days,
    required this.repossessionFee,
    required this.terminationSmsEnabled,
    required this.confirmationSmsEnabled,
    required this.paymentSmsEnabled,
    required this.whatsappPhone,
    required this.messageChannel,
    required this.waReady,
    required this.templates,
  });

  factory ContractSettings.fromJson(Map<String, dynamic> json) {
    final rules = json['rules'] as Map<String, dynamic>? ?? {};
    final templates = json['templates'] as Map<String, dynamic>? ?? {};
    return ContractSettings(
      penaltyPerDay: '${rules['penalty_per_day'] ?? '0'}',
      penaltyGraceDays: '${rules['penalty_grace_days'] ?? '0'}',
      terminationGraceDays: '${rules['termination_grace_days'] ?? '0'}',
      reminderSmsEnabled: rules['reminder_sms_enabled'] == true,
      stage2Days: '${rules['stage2_days'] ?? '0'}',
      stage3Days: '${rules['stage3_days'] ?? '0'}',
      repossessionFee: '${rules['repossession_fee'] ?? '0'}',
      terminationSmsEnabled: rules['termination_sms_enabled'] == true,
      confirmationSmsEnabled: rules['confirmation_sms_enabled'] == true,
      paymentSmsEnabled: rules['payment_sms_enabled'] == true,
      whatsappPhone: '${rules['whatsapp_phone'] ?? ''}',
      messageChannel: '${rules['message_channel'] ?? 'sms'}',
      waReady: rules['wa_ready'] == true,
      templates: templates.map((k, v) => MapEntry(k, '$v')),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'rules': {
        'penalty_per_day': penaltyPerDay,
        'penalty_grace_days': penaltyGraceDays,
        'termination_grace_days': terminationGraceDays,
        'reminder_sms_enabled': reminderSmsEnabled,
        'stage2_days': stage2Days,
        'stage3_days': stage3Days,
        'repossession_fee': repossessionFee,
        'termination_sms_enabled': terminationSmsEnabled,
        'confirmation_sms_enabled': confirmationSmsEnabled,
        'payment_sms_enabled': paymentSmsEnabled,
        'whatsapp_phone': whatsappPhone,
        'message_channel': messageChannel,
      },
      'templates': templates,
    };
  }

  ContractSettings copyWith({
    String? penaltyPerDay,
    String? penaltyGraceDays,
    String? terminationGraceDays,
    bool? reminderSmsEnabled,
    String? stage2Days,
    String? stage3Days,
    String? repossessionFee,
    bool? terminationSmsEnabled,
    bool? confirmationSmsEnabled,
    bool? paymentSmsEnabled,
    String? whatsappPhone,
    String? messageChannel,
    Map<String, String>? templates,
  }) {
    return ContractSettings(
      penaltyPerDay: penaltyPerDay ?? this.penaltyPerDay,
      penaltyGraceDays: penaltyGraceDays ?? this.penaltyGraceDays,
      terminationGraceDays: terminationGraceDays ?? this.terminationGraceDays,
      reminderSmsEnabled: reminderSmsEnabled ?? this.reminderSmsEnabled,
      stage2Days: stage2Days ?? this.stage2Days,
      stage3Days: stage3Days ?? this.stage3Days,
      repossessionFee: repossessionFee ?? this.repossessionFee,
      terminationSmsEnabled:
          terminationSmsEnabled ?? this.terminationSmsEnabled,
      confirmationSmsEnabled:
          confirmationSmsEnabled ?? this.confirmationSmsEnabled,
      paymentSmsEnabled: paymentSmsEnabled ?? this.paymentSmsEnabled,
      whatsappPhone: whatsappPhone ?? this.whatsappPhone,
      messageChannel: messageChannel ?? this.messageChannel,
      waReady: waReady,
      templates: templates ?? this.templates,
    );
  }
}
