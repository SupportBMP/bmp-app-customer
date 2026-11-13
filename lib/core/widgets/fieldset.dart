import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../theme/app_colors.dart';
import '../theme/app_text.dart';
import '../utils/json.dart';
import 'site_image.dart';
import 'ui.dart';
import 'native.dart';

/// The legacy `<fieldset><legend>` inputs (components/InputComponent/*):
/// a light-grey outlined box with the label notched into the top border.
InputDecoration fieldsetDecoration(String label, {bool required = false, String? hint, Widget? prefix}) {
  const border = OutlineInputBorder(
    borderRadius: BorderRadius.all(Radius.circular(6)),
    borderSide: BorderSide(color: AppColors.lightGrey),
  );
  return InputDecoration(
    labelText: '$label${required ? '*' : ''}',
    labelStyle: AppText.poppins(size: 12, color: AppColors.foreground),
    floatingLabelStyle: AppText.poppins(size: 12, color: AppColors.foreground),
    floatingLabelBehavior: FloatingLabelBehavior.always,
    hintText: hint,
    hintStyle: AppText.poppins(size: 14, color: AppColors.phDefault),
    prefixIcon: prefix,
    prefixIconConstraints: const BoxConstraints(minWidth: 40, minHeight: 16),
    filled: false,
    isDense: true,
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
    border: border,
    enabledBorder: border,
    disabledBorder: border,
    focusedBorder: border.copyWith(borderSide: const BorderSide(color: AppColors.defaultText)),
  );
}

Widget fieldsetIcon(String? image) => Padding(
      padding: const EdgeInsets.only(left: 16, right: 8),
      child: SiteImage(image ?? '/icons/Profile_Red.svg', width: 16, height: 16, fit: BoxFit.contain, placeholderColor: Colors.transparent),
    );

/// `transformFields` from utils/utils.jsx: CMS form fields → input specs.
Map<String, Json> transformFields(List<Json> fields) {
  const mapping = {
    'number': 'number',
    'input': 'text',
    'dropdown': 'select',
    'datetime': 'datetime',
    'toggle': 'boolean',
    'textarea': 'textarea',
    'radio': 'select',
    'date': 'date',
  };
  final out = <String, Json>{};
  for (var i = 0; i < fields.length; i++) {
    final f = fields[i];
    final name = str(f['fieldName']).replaceAll(' ', '');
    out[name] = {
      'type': mapping[str(f['fieldType'])] ?? 'text',
      'placeholder': strOrNull(f['placeholder']) ?? 'Enter ${str(f['fieldLabel'])}',
      'required': boolOf(f['isRequired']),
      'label': str(f['fieldLabel']),
      'priority': i + 1,
      'inputKey': name,
      if (str(f['fieldType']) == 'dropdown' || str(f['fieldType']) == 'radio')
        'options': list(f['options']).map((o) => {'value': '$o', 'label': '$o'}).toList(),
    };
  }
  return out;
}

/// One input of a CMS-defined form (BlogModalComponent's switch on `type`).
class DynamicFormField extends StatelessWidget {
  const DynamicFormField({super.key, required this.spec, required this.value, required this.onChanged});
  final Json spec;
  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final type = str(spec['type']);
    final label = str(spec['label']);
    final required = boolOf(spec['required']);
    final hint = strOrNull(spec['placeholder']);
    switch (type) {
      case 'select':
        final options = objList(spec['options']);
        return InputDecorator(
          decoration: fieldsetDecoration(label, required: required),
          child: GestureDetector(
            onTap: () async {
              final v = await showPickerSheet<String>(
                context,
                title: 'Select $label',
                options: options.map((o) => str(o['value'])).toList(),
                labelOf: (v) => str(options.firstWhere((o) => str(o['value']) == v)['label']),
                selected: value.isEmpty ? null : value,
              );
              if (v != null) onChanged(v);
            },
            child: Text(
              value.isEmpty ? 'Select $label' : value,
              style: AppText.poppins(size: 14, color: AppColors.defaultText.o(value.isEmpty ? .5 : 1)),
            ),
          ),
        );
      case 'date':
        return InputDecorator(
          decoration: fieldsetDecoration(label, required: required),
          child: GestureDetector(
            onTap: () async {
              final now = DateTime.now();
              final d = await showNativeDatePicker(context, initialDate: now, firstDate: DateTime(1900), lastDate: DateTime(now.year + 5));
              if (d != null) onChanged(DateFormat('yyyy-MM-dd').format(d));
            },
            child: Text(
              value.isEmpty ? 'Date of birth' : value,
              style: AppText.poppins(size: 14, color: AppColors.defaultText.o(value.isEmpty ? .5 : 1)),
            ),
          ),
        );
      case 'textarea':
        return TextFormField(
          initialValue: value,
          onChanged: onChanged,
          minLines: 3,
          maxLines: 3,
          style: AppText.poppins(size: 14, color: AppColors.defaultText),
          decoration: fieldsetDecoration(label, required: required, hint: hint, prefix: fieldsetIcon(strOrNull(spec['image']))),
        );
      default:
        return TextFormField(
          initialValue: value,
          onChanged: onChanged,
          keyboardType: type == 'number' ? TextInputType.number : TextInputType.text,
          style: AppText.poppins(size: 14, color: AppColors.defaultText),
          decoration: fieldsetDecoration(label, required: required, hint: hint, prefix: fieldsetIcon(strOrNull(spec['image']))),
        );
    }
  }
}
