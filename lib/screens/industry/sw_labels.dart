// Swahili labels matching the web dashboard's Industry section, so the app
// reads the same as what ARG's staff already see on web. Falls back to a
// titleized English label for any key not in this map (new/unconfirmed
// backend fields still show up, just untranslated, rather than disappearing).
const Map<String, String> swLabels = {
  // Section titles
  'labourers': 'Wafanyakazi wa Kibarua & Malipo',
  'roller': 'Roller',
  'mattress': 'Magodoro',
  'production': 'Uzalishaji (Production)',
  'pcs_produced': 'Pcs Zilizozalishwa',
  'stock': 'Stock ya Sasa Hivi',

  // Day/Week headers and date controls
  'today': 'Siku Hii',
  'this_week': 'Wiki Hii',
  'change_date': 'Badilisha Tarehe',
  'week': 'Wiki',

  // Labourers & Payments fields (confirmed live: present/total/gross/penalty)
  'present': 'Waliokuja',
  'total': 'Jumla Wafanyakazi',
  'days_attended': 'Siku Zilizohudhuriwa',
  'gross': 'Malipo Kabla ya Makato',
  'gross_earned': 'Malipo Kabla ya Makato',
  'penalty': 'Makato ya Kuchelewa',
  'adjustment': 'Malipo ya Dharura',
  'net': 'Jumla ya Malipo',
  'amount': 'Jumla ya Malipo',
  'amount_earned': 'Jumla ya Malipo',
  'paid_count': 'Waliolipwa',
  'unpaid_count': 'Hawajalipwa',

  // Roller fields
  'bags_received': 'Roba Zilizopokelewa',
  'bags_opened': 'Roba Zilizofunguliwa',
  'rollers_counted_big': 'Rollers Zilizovishwa (Big Roller)',
  'rollers_counted_small': 'Rollers Zilizovishwa (Small Roller)',
  'rollers_used_big': 'Rollers Zilizovishwa (Big Roller)',
  'rollers_used_small': 'Rollers Zilizovishwa (Small Roller)',
  'straps_used': 'Mikanda Iliyotumika (Kuvisha)',
  'trimmed_big': 'Rollers Zilizopruniwa (Big Roller)',
  'trimmed_small': 'Rollers Zilizopruniwa (Small Roller)',
  'straps_welded': 'Mikanda Iliyochomwa',

  // Mattress fields
  'mattresses_received': 'Magodoro Yaliyopokelewa',
  'mattresses_cut': 'Magodoro Yaliyochanwa',
  'straps_actual': 'Mikanda Halisi',
  'straps_damaged': 'Mikanda Iliyoharibika',
  'straps_in_hand': 'Mikanda Iliyopo',

  // Production fields
  'quantity_produced': 'Pcs Zilizozalishwa (Mashine)',
  'dozens_packed': 'Dazeni Zilizopack',
  'cartons_packed': 'Katoni Zilizopack',
  'cartons_issued': 'Katoni Zilizotolewa (Issue)',

  // Stock section
  'machine': 'Mashine',
  'pcs_in_hand': 'Pcs Zilizopo',
  'dozens_in_hand': 'Dazeni Zilizopo',
  'cartons_in_hand': 'Katoni Zilizopo',
};

String swLabel(String key) {
  final normalized = key.toLowerCase();
  if (swLabels.containsKey(normalized)) return swLabels[normalized]!;

  // Fall back to titleized English for anything not yet mapped.
  return key
      .split('_')
      .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
      .join(' ');
}
