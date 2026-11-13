import 'package:flutter/material.dart';

import '../../core/api/bmp_api.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/utils/json.dart';
import '../../core/widgets/site_image.dart';
import '../../core/widgets/toast.dart';
import '../../core/widgets/ui.dart';
import '../address/address_widgets.dart';
import 'profile_page.dart';

/// pages/user/address.jsx — the address form opens the same map → form flow
/// used at checkout.
class AddressPage extends StatefulWidget {
  const AddressPage({super.key});

  @override
  State<AddressPage> createState() => _AddressPageState();
}

class _AddressPageState extends State<AddressPage> {
  List<Json> _addresses = [];
  Json _user = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetchUser();
    _fetch();
  }

  Future<void> _fetchUser() async {
    try {
      final r = await BmpApi.userDetails();
      final d = obj(r.data);
      if (r.statusCode == 200 && intOf(d['statusCode']) == 200) _user = obj(d['body']);
    } catch (_) {}
  }

  Future<void> _fetch() async {
    setState(() => _loading = true);
    try {
      final r = await BmpApi.userAddresses();
      final d = obj(r.data);
      if (r.statusCode == 200) {
        if (intOf(d['statusCode']) == 200) _addresses = objList(d['body']);
      } else {
        Toast.error('Error Fetching Address Response');
      }
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _openForm([Json? edit]) async {
    final data = await openAddressFlow(context, userData: _user, editAddress: edit);
    if (data == null) return;
    final editId = strOrNull(data['editAddressId']);
    try {
      if (editId != null) {
        final r = await BmpApi.updateAddress(editId, data);
        if (r.statusCode == 200 && intOf(obj(r.data)['statusCode']) == 200) {
          Toast.show('Address Updated Successfully');
        } else {
          Toast.show('Error updating address');
        }
      } else {
        await BmpApi.addAddress(data);
      }
    } catch (_) {
      Toast.show('Error updating address');
    }
    _fetch();
  }

  Future<void> _remove(String id) async {
    try {
      final r = await BmpApi.removeAddress(id);
      if (r.statusCode == 200 && intOf(obj(r.data)['statusCode']) == 200) {
        setState(() => _addresses = _addresses.where((a) => str(a['_id']) != id).toList());
      } else {
        Toast.error('Something Went Wrong!');
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return UserShell(padding: const EdgeInsets.fromLTRB(32 + 16, 16, 32 + 16, 16), children: [
      if (_loading)
        const AppSpinner()
      else ...[
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Align(
            alignment: Alignment.centerRight,
            child: GestureDetector(
              onTap: () => _openForm(),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0x4D8A1C23)),
                ),
                child: Text('ADD NEW', style: AppText.poppins(size: 14, weight: FontWeight.w500, color: AppColors.bluntRed)),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        if (_addresses.isEmpty)
          Text('No addresses found.', textAlign: TextAlign.center, style: AppText.poppins(size: 30, weight: FontWeight.w600, color: AppColors.bluntRed))
        else
          for (final a in _addresses)
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.profileBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.headerQuote),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  const SiteImage('/icons/home-address.svg', width: 16, height: 16, placeholderColor: Colors.transparent),
                  const SizedBox(width: 8),
                  Expanded(child: Text(str(a['name']), style: AppText.poppins(size: 14, weight: FontWeight.w500, color: AppColors.defaultText))),
                  PopupMenuButton<String>(
                    color: Colors.white,
                    constraints: const BoxConstraints(minWidth: 144),
                    onSelected: (v) {
                      if (v == 'edit') _openForm(a);
                      if (v == 'remove') _remove(str(a['_id']));
                    },
                    itemBuilder: (_) => [
                      PopupMenuItem(value: 'edit', height: 32, child: Text('Edit', style: AppText.poppins(size: 14))),
                      PopupMenuItem(value: 'default', height: 32, child: Text('Make Default', style: AppText.poppins(size: 14))),
                      PopupMenuItem(
                          value: 'remove', height: 32, child: Text('Remove', style: AppText.poppins(size: 14, color: AppColors.darkOrange))),
                    ],
                    child: const Padding(
                      padding: EdgeInsets.all(4),
                      child: SiteImage('/icons/three-dot-menu.svg', width: 16, height: 16, placeholderColor: Colors.transparent),
                    ),
                  ),
                ]),
                const SizedBox(height: 8),
                Text(
                  '${str(a['areaLocation'])}, ${str(a['landmark'])}\n'
                  '${str(a['city'])}, ${str(a['state'])} - ${str(a['pincode'])}, (${str(a['country'])})\n'
                  'Mobile: ${str(a['phoneNumber'])}',
                  style: AppText.poppins(size: 14, color: AppColors.defaultText, height: 20 / 14),
                ),
              ]),
            ),
      ],
    ]);
  }
}
