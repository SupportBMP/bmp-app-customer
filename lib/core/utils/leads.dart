/// commons/constants.js `CRM_LEADS_FIELD_MAP` and utils `createCRMLeadEnquiryBody`.
library;

const crmLeadsFieldMap = <String, String>{
  'phone': 'phone',
  'name': 'fullName',
  'email': 'email',
  'city': 'city',
  'pujaType': 'pooja-enquired',
  'date': 'booking_date',
  // The website's key really carries a combining comma below (U+0326).
  'otherDetails': 'enquiry̦',
  'enquiry': 'enquiry',
  'language': 'language',
  'pooja-enquired': 'pooja-enquired',
};

Map<String, dynamic> createCrmLeadEnquiryBody(Map<String, dynamic> form) {
  final body = <String, dynamic>{};
  crmLeadsFieldMap.forEach((key, field) {
    if (key != 'otherDetails' && form.containsKey(key) && form[key] != null) {
      body[field] = '${form[key]}';
    }
  });
  final other = form.keys.where((k) => !crmLeadsFieldMap.containsKey(k)).map((k) => '$k: ${form[k]}').toList();
  if (other.isNotEmpty) body[crmLeadsFieldMap['otherDetails']!] = other.join(' | ');
  return body;
}

/// Indian mobile check used by the website's lead forms.
bool isValidIndianMobile(String phone) => RegExp(r'^[6-9]\d{9}$').hasMatch(phone);

String titleCase(String s) => s
    .replaceAll('-', ' ')
    .replaceAllMapped(RegExp(r'\b\w'), (m) => m.group(0)!.toUpperCase());
