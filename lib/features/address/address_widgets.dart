import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../core/config.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/utils/json.dart';
import '../../core/widgets/site_image.dart';
import '../../core/widgets/toast.dart';

/// Full-screen modal (`fixed inset-0 … w-full h-full` on phones) with the
/// legacy header: title + Cancelbutton.svg.
Future<T?> pushFullScreenModal<T>(BuildContext context, {required String title, required WidgetBuilder body}) {
  return Navigator.of(context).push<T>(
    PageRouteBuilder(
      opaque: false,
      barrierColor: AppColors.black40,
      pageBuilder: (ctx, _, _) => Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Column(children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.gray200))),
              child: Row(children: [
                Expanded(child: Text(title, style: AppText.poppins(size: 16, weight: FontWeight.w600))),
                GestureDetector(
                  onTap: () => Navigator.of(ctx).pop(),
                  child: const SiteImage('/icons/Cancelbutton.svg', width: 16, height: 16, placeholderColor: Colors.transparent),
                ),
              ]),
            ),
            Expanded(child: Builder(builder: body)),
          ]),
        ),
      ),
      transitionsBuilder: (_, a, _, child) => FadeTransition(opacity: a, child: child),
    ),
  );
}

// ---------------------------------------------------------------------------
// AddressFlowModal.jsx — MAP step (new address) then FORM step.
// ---------------------------------------------------------------------------

/// Opens the add / edit address flow; resolves with the form data (plus
/// `editAddressId`) once "SAVE ADDRESS" is tapped.
Future<Json?> openAddressFlow(BuildContext context, {required Json userData, Json? editAddress}) {
  return Navigator.of(context).push<Json>(
    MaterialPageRoute(fullscreenDialog: true, builder: (_) => _AddressFlowScreen(userData: userData, editAddress: editAddress)),
  );
}

class _AddressFlowScreen extends StatefulWidget {
  const _AddressFlowScreen({required this.userData, this.editAddress});
  final Json userData;
  final Json? editAddress;

  @override
  State<_AddressFlowScreen> createState() => _AddressFlowScreenState();
}

class _AddressFlowScreenState extends State<_AddressFlowScreen> {
  late String _step = widget.editAddress != null ? 'FORM' : 'MAP';
  Json _coords = {};
  Json _auto = {};

  @override
  void initState() {
    super.initState();
    _coords = obj(widget.editAddress?['coordinates']);
  }

  Json get _initial {
    final e = widget.editAddress ?? const <String, dynamic>{};
    final u = widget.userData;
    return {
      'name': strOrNull(e['name']) ?? str(u['userName']),
      'userDataEmail': str(u['email']),
      'email': strOrNull(e['email']) ?? str(u['email']),
      'phoneNumber': strOrNull(e['phoneNumber']) ?? str(u['phone']),
      'pincode': strOrNull(e['pincode']) ?? str(_auto['pincode']),
      'areaLocation': strOrNull(e['areaLocation']) ?? str(_auto['areaLocation']),
      'landmark': strOrNull(e['landmark']) ?? str(_auto['landmark']),
      'city': strOrNull(e['city']) ?? str(_auto['city']),
      'state': strOrNull(e['state']) ?? str(_auto['state']),
      'country': 'India',
      'default': boolOf(e['default']),
      'coordinates': _coords,
    };
  }

  @override
  Widget build(BuildContext context) {
    final title = _step == 'MAP'
        ? 'Select puja location'
        : widget.editAddress != null
            ? 'Edit address'
            : 'Add new address';
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.gray200))),
            child: Row(children: [
              Expanded(child: Text(title, style: AppText.poppins(size: 16, weight: FontWeight.w600))),
              GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: const SiteImage('/icons/Cancelbutton.svg', width: 16, height: 16, placeholderColor: Colors.transparent),
              ),
            ]),
          ),
          Expanded(
            child: _step == 'MAP'
                ? MapPicker(
                    onContinue: (coords, place) => setState(() {
                      _coords = coords;
                      _auto = normalizeGoogleAddress(place);
                      _step = 'FORM';
                    }),
                  )
                : AddressForm(
                    key: ValueKey(_auto.hashCode),
                    initialData: _initial,
                    onSubmit: (data) => Navigator.of(context).pop({...data, 'editAddressId': widget.editAddress?['_id']}),
                  ),
          ),
        ]),
      ),
    );
  }
}

/// normalizeGoogleAddress.js
Json normalizeGoogleAddress(Json? place) {
  final comps = objList(place?['address_components']);
  if (comps.isEmpty) return {};
  String get(String type) =>
      str(comps.firstWhere((c) => list(c['types']).contains(type), orElse: () => const {})['long_name']);
  return {
    'pincode': get('postal_code'),
    'city': get('locality').isNotEmpty ? get('locality') : get('administrative_area_level_2'),
    'state': get('administrative_area_level_1'),
    'areaLocation': get('sublocality').isNotEmpty ? get('sublocality') : get('route'),
    'landmark': '',
  };
}

// ---------------------------------------------------------------------------
// GMapsComponent.jsx — tap to drop a pin, search places, current location.
// ---------------------------------------------------------------------------

class MapPicker extends StatefulWidget {
  const MapPicker({super.key, required this.onContinue});
  final void Function(Json coordinates, Json? place) onContinue;

  @override
  State<MapPicker> createState() => _MapPickerState();
}

class _MapPickerState extends State<MapPicker> {
  static const _center = LatLng(12.97927, 77.653038);
  GoogleMapController? _map;
  LatLng? _marker;
  String _address = '';
  Json? _place;
  final _search = TextEditingController();
  List<Json> _predictions = [];
  Timer? _debounce;
  final _dio = Dio();

  String get _key => AppConfig.googleApiKey;

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  Future<void> _geocode(LatLng p) async {
    try {
      final r = await _dio.get('https://maps.googleapis.com/maps/api/geocode/json',
          queryParameters: {'latlng': '${p.latitude},${p.longitude}', 'key': _key});
      final results = objList(obj(r.data)['results']);
      if (results.isNotEmpty) {
        setState(() {
          _place = results.first;
          _address = str(results.first['formatted_address']);
        });
      }
    } catch (_) {}
  }

  void _onSearch(String q) {
    _debounce?.cancel();
    if (q.trim().isEmpty) {
      setState(() => _predictions = []);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 300), () async {
      try {
        final r = await _dio.get('https://maps.googleapis.com/maps/api/place/autocomplete/json',
            queryParameters: {'input': q, 'key': _key, 'components': 'country:in'});
        if (mounted) setState(() => _predictions = objList(obj(r.data)['predictions']));
      } catch (_) {}
    });
  }

  Future<void> _pickPrediction(Json p) async {
    setState(() => _predictions = []);
    FocusScope.of(context).unfocus();
    try {
      final r = await _dio.get('https://maps.googleapis.com/maps/api/place/details/json',
          queryParameters: {'place_id': str(p['place_id']), 'key': _key, 'fields': 'address_component,formatted_address,geometry'});
      final place = obj(obj(r.data)['result']);
      final loc = obj(pick(place, ['geometry', 'location']));
      final pos = LatLng(dbl(loc['lat']), dbl(loc['lng']));
      setState(() {
        _place = place;
        _marker = pos;
        _address = str(place['formatted_address']);
        _search.text = str(p['description']);
      });
      _map?.animateCamera(CameraUpdate.newLatLng(pos));
    } catch (_) {}
  }

  Future<void> _currentLocation() async {
    setState(() => _predictions = []);
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
        Toast.error('Error getting current location: ');
        return;
      }
      final p = await Geolocator.getCurrentPosition();
      final pos = LatLng(p.latitude, p.longitude);
      setState(() => _marker = pos);
      _map?.animateCamera(CameraUpdate.newLatLng(pos));
      _geocode(pos);
    } catch (_) {
      Toast.error('Error getting current location: ');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Expanded(
        child: Stack(children: [
          GoogleMap(
            initialCameraPosition: const CameraPosition(target: _center, zoom: 10),
            onMapCreated: (c) => _map = c,
            onTap: (p) {
              setState(() => _marker = p);
              _geocode(p);
            },
            markers: {if (_marker != null) Marker(markerId: const MarkerId('pin'), position: _marker!)},
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
          ),
          Positioned(
            top: 8,
            left: 8,
            right: MediaQuery.sizeOf(context).width * .25,
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Container(
                height: 40,
                color: Colors.white,
                child: TextField(
                  controller: _search,
                  onChanged: _onSearch,
                  onTap: () => setState(() {}),
                  style: AppText.poppins(size: 14),
                  decoration: InputDecoration(
                    hintText: 'Search for places',
                    filled: false,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: const EdgeInsets.all(8),
                    hintStyle: AppText.poppins(size: 14, color: AppColors.gray500),
                  ),
                ),
              ),
              if (_predictions.isNotEmpty || _search.text.isNotEmpty)
                Material(
                  color: Colors.white,
                  elevation: 2,
                  child: Column(children: [
                    _pacItem('Current Location', _currentLocation),
                    for (final p in _predictions) _pacItem(str(p['description']), () => _pickPrediction(p)),
                  ]),
                ),
            ]),
          ),
        ]),
      ),
      if (_address.isNotEmpty)
        Padding(
          padding: const EdgeInsets.all(16),
          child: Align(alignment: Alignment.centerLeft, child: Text(_address, style: AppText.poppins(size: 14))),
        ),
      Container(
        padding: const EdgeInsets.all(16),
        decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.gray200))),
        child: _redButton('Continue', () {
          final m = _marker;
          if (m == null) {
            Toast.error('Please select a location on the map');
            return;
          }
          widget.onContinue({'lat': m.latitude, 'lng': m.longitude}, _place);
        }),
      ),
    ]);
  }

  Widget _pacItem(String text, VoidCallback onTap) => InkWell(
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          decoration: const BoxDecoration(border: Border(top: BorderSide(color: Color(0xFFE6E6E6)))),
          child: Text(text, style: AppText.sans(size: 12, color: const Color(0xFF515151))),
        ),
      );
}

Widget _redButton(String label, VoidCallback? onTap, {bool outlined = false, double vertical = 14}) => Material(
      color: onTap == null ? AppColors.gray300 : (outlined ? Colors.white : AppColors.bluntRed),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: onTap == null ? AppColors.gray300 : AppColors.bluntRed),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: vertical),
          child: Center(
            child: Text(
              label,
              style: AppText.poppins(size: 14, weight: FontWeight.w500, color: outlined ? AppColors.bluntRed : Colors.white),
            ),
          ),
        ),
      ),
    );

// ---------------------------------------------------------------------------
// AddressForm.jsx + addressFormConfig.js
// ---------------------------------------------------------------------------

class AddressForm extends StatefulWidget {
  const AddressForm({super.key, required this.initialData, required this.onSubmit});
  final Json initialData;
  final ValueChanged<Json> onSubmit;

  @override
  State<AddressForm> createState() => _AddressFormState();
}

class _AddressFormState extends State<AddressForm> {
  late final Json _data = Map.of(widget.initialData);
  final Map<String, TextEditingController> _c = {};
  CancelToken? _pinCancel;

  static const _sections = [
    ('Contact Details', [
      ('name', 'Name', true),
      ('phoneNumber', 'Phone No', true),
      ('email', 'Email', true),
    ]),
    ('Address', [
      ('pincode', 'Pincode', true),
      ('areaLocation', 'Flat No., Building Name & Area / Location', true),
      ('landmark', 'Landmark', false),
      ('city', 'City', true),
      ('state', 'State', true),
    ]),
  ];

  TextEditingController _ctl(String key) => _c.putIfAbsent(key, () => TextEditingController(text: str(_data[key])));

  @override
  void dispose() {
    for (final c in _c.values) {
      c.dispose();
    }
    super.dispose();
  }

  bool _disabled(String key) =>
      key == 'phoneNumber' || (key == 'email' && str(_data['userDataEmail']).isNotEmpty);

  Map<String, String> get _errors {
    final e = <String, String>{};
    for (final s in _sections) {
      for (final f in s.$2) {
        if (f.$3 && str(_data[f.$1]).isEmpty) e[f.$1] = '${f.$2} is required';
      }
    }
    return e;
  }

  Future<void> _validatePincode(String pincode) async {
    if (pincode.length != 6) return;
    _pinCancel?.cancel();
    _pinCancel = CancelToken();
    try {
      final r = await Dio().get('https://api.postalpincode.in/pincode/$pincode', cancelToken: _pinCancel);
      final d = list(r.data);
      if (d.isNotEmpty && str(obj(d.first)['Status']) == 'Success') {
        final po = obj(list(obj(d.first)['PostOffice']).first);
        setState(() {
          _data['city'] = str(po['District']);
          _data['state'] = str(po['State']);
          _ctl('city').text = _data['city'];
          _ctl('state').text = _data['state'];
        });
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final errors = _errors;
    return Column(children: [
      Expanded(
        child: ListView(
          padding: const EdgeInsets.only(bottom: 16),
          children: [
            for (final s in _sections)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Text(s.$1, style: AppText.poppins(size: 14, weight: FontWeight.w500)),
                  const SizedBox(height: 12),
                  for (final f in s.$2)
                    if (f.$1 != 'landmark' || str(_data['areaLocation']).isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          TextField(
                            controller: _ctl(f.$1),
                            enabled: !_disabled(f.$1),
                            keyboardType: f.$1 == 'pincode' ? TextInputType.number : null,
                            style: AppText.poppins(size: 14, color: _disabled(f.$1) ? AppColors.gray400 : AppColors.foreground),
                            onChanged: (v) {
                              setState(() => _data[f.$1] = v);
                              if (f.$1 == 'pincode') _validatePincode(v);
                            },
                            decoration: _legend('${f.$2} ${f.$3 ? '*' : ''}'),
                          ),
                          if (errors[f.$1] != null)
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                              child: Text(errors[f.$1]!, style: AppText.poppins(size: 12, color: AppColors.red500)),
                            ),
                        ]),
                      ),
                  if (s.$1 == 'Address')
                    GestureDetector(
                      onTap: () => setState(() => _data['default'] = !boolOf(_data['default'])),
                      child: Row(children: [
                        Checkbox(
                          value: boolOf(_data['default']),
                          onChanged: (v) => setState(() => _data['default'] = v ?? false),
                          visualDensity: VisualDensity.compact,
                        ),
                        Text('Make this default address', style: AppText.poppins(size: 14)),
                      ]),
                    ),
                ]),
              ),
          ],
        ),
      ),
      Container(
        padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + MediaQuery.paddingOf(context).bottom),
        decoration: const BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: AppColors.gray200))),
        child: _redButton('SAVE ADDRESS', errors.isEmpty ? () => widget.onSubmit(Map.of(_data)) : null, vertical: 12),
      ),
    ]);
  }

  InputDecoration _legend(String label) {
    const b = OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(6)), borderSide: BorderSide(color: AppColors.lightGrey));
    return InputDecoration(
      labelText: label.trim(),
      labelStyle: AppText.poppins(size: 12),
      floatingLabelStyle: AppText.poppins(size: 12),
      floatingLabelBehavior: FloatingLabelBehavior.always,
      filled: false,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: b,
      enabledBorder: b,
      disabledBorder: b,
      focusedBorder: b,
    );
  }
}

// ---------------------------------------------------------------------------
// AddressListing.jsx + AddressCard.jsx + ConfirmDeleteModal.jsx
// ---------------------------------------------------------------------------

/// Opens "Select Address"; resolves with the chosen address.
Future<Json?> openAddressListing(
  BuildContext context, {
  required List<Json> addresses,
  required Future<List<Json>> Function() fetchAddresses,
  required Future<void> Function(Json data) handleAddAddress,
  required Future<void> Function(String id) handleDeleteAddress,
  required Json userData,
  Json? defaultAddress,
}) {
  return Navigator.of(context).push<Json>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => _AddressListingScreen(
        addresses: addresses,
        fetchAddresses: fetchAddresses,
        handleAddAddress: handleAddAddress,
        handleDeleteAddress: handleDeleteAddress,
        userData: userData,
        defaultAddress: defaultAddress,
      ),
    ),
  );
}

class _AddressListingScreen extends StatefulWidget {
  const _AddressListingScreen({
    required this.addresses,
    required this.fetchAddresses,
    required this.handleAddAddress,
    required this.handleDeleteAddress,
    required this.userData,
    this.defaultAddress,
  });

  final List<Json> addresses;
  final Future<List<Json>> Function() fetchAddresses;
  final Future<void> Function(Json data) handleAddAddress;
  final Future<void> Function(String id) handleDeleteAddress;
  final Json userData;
  final Json? defaultAddress;

  @override
  State<_AddressListingScreen> createState() => _AddressListingScreenState();
}

class _AddressListingScreenState extends State<_AddressListingScreen> {
  late List<Json> _addresses = widget.addresses;
  Json? _selected;

  @override
  void initState() {
    super.initState();
    _selected = _addresses.where((a) => str(a['_id']) == str(widget.defaultAddress?['_id'])).firstOrNull;
    if (_addresses.isEmpty) WidgetsBinding.instance.addPostFrameCallback((_) => _addOrEdit(null));
  }

  Future<void> _refresh() async {
    final list = await widget.fetchAddresses();
    if (!mounted) return;
    setState(() {
      _addresses = list;
      if (_selected != null && !_addresses.any((a) => str(a['_id']) == str(_selected!['_id']))) _selected = null;
    });
  }

  Future<void> _addOrEdit(Json? edit) async {
    final data = await openAddressFlow(context, userData: widget.userData, editAddress: edit);
    if (data == null) return;
    await widget.handleAddAddress(data);
    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.gray200))),
            child: Row(children: [
              Expanded(child: Text('Select Address', style: AppText.poppins(size: 18, weight: FontWeight.w600))),
              GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: const SiteImage('/icons/Cancelbutton.svg', width: 16, height: 16, placeholderColor: Colors.transparent),
              ),
            ]),
          ),
          Expanded(
            child: _addresses.isEmpty
                ? Padding(
                    padding: const EdgeInsets.only(top: 40),
                    child: Text('No addresses found. Please add one to continue.',
                        textAlign: TextAlign.center, style: AppText.poppins(size: 14, color: AppColors.gray500)),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _addresses.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (_, i) {
                      final a = _addresses[i];
                      return AddressCard(
                        address: a,
                        isSelected: str(_selected?['_id']) == str(a['_id']),
                        onSelect: () => setState(() => _selected = a),
                        onEdit: () => _addOrEdit(a),
                        onDelete: () async {
                          final ok = await confirmDelete(context, 'Delete Address?', 'This address will be permanently removed.');
                          if (ok != true) return;
                          await widget.handleDeleteAddress(str(a['_id']));
                          await _refresh();
                        },
                      );
                    },
                  ),
          ),
          if (_addresses.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.gray200))),
              child: Column(children: [
                if (_selected != null) ...[
                  _redButton('Proceed with this Puja Address', () => Navigator.of(context).pop(_selected), vertical: 12),
                  const SizedBox(height: 12),
                ],
                _redButton('+ Add New Address', () => _addOrEdit(null), outlined: true, vertical: 12),
              ]),
            ),
        ]),
      ),
    );
  }
}

class AddressCard extends StatelessWidget {
  const AddressCard({super.key, required this.address, required this.isSelected, required this.onSelect, required this.onEdit, required this.onDelete});
  final Json address;
  final bool isSelected;
  final VoidCallback onSelect;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    const maroon = Color(0xFF7B1520);
    return GestureDetector(
      onTap: onSelect,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFFFF1F2) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isSelected ? maroon : AppColors.gray100, width: 2),
          boxShadow: isSelected ? const [BoxShadow(color: Color(0x1A000000), blurRadius: 6, offset: Offset(0, 4))] : null,
        ),
        child: Stack(children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Padding(
              padding: const EdgeInsets.only(right: 32),
              child: Wrap(crossAxisAlignment: WrapCrossAlignment.center, children: [
                Text(str(address['name']),
                    style: AppText.poppins(size: 14, weight: FontWeight.w600, color: isSelected ? maroon : AppColors.gray800)),
                if (boolOf(address['default']))
                  Container(
                    margin: const EdgeInsets.only(left: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: AppColors.green100, borderRadius: BorderRadius.circular(999)),
                    child: Text('Default', style: AppText.poppins(size: 10, weight: FontWeight.w700, color: AppColors.green600)),
                  ),
              ]),
            ),
            const SizedBox(height: 6),
            Text(
              '${str(address['areaLocation'])}, ${str(address['city'])}, ${str(address['state'])} — ${str(address['pincode'])}',
              style: AppText.poppins(size: 12, color: AppColors.gray500, height: 20 / 12),
            ),
            const SizedBox(height: 2),
            Text('📞 ${str(address['phoneNumber'])}', style: AppText.poppins(size: 12, color: AppColors.gray500)),
            const SizedBox(height: 12),
            Row(children: [
              GestureDetector(
                onTap: onEdit,
                child: Text('Edit', style: AppText.poppins(size: 12, weight: FontWeight.w600, color: AppColors.blue600)),
              ),
              const SizedBox(width: 12),
              GestureDetector(
                onTap: onDelete,
                child: Text('Delete', style: AppText.poppins(size: 12, weight: FontWeight.w600, color: AppColors.red500)),
              ),
            ]),
          ]),
          Positioned(
            top: -4,
            right: -4,
            child: Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected ? maroon : Colors.white,
                border: Border.all(color: isSelected ? maroon : AppColors.gray300, width: 2),
              ),
              child: isSelected ? const Icon(Icons.check, size: 12, color: Colors.white) : null,
            ),
          ),
        ]),
      ),
    );
  }
}

/// ConfirmDeleteModal.jsx
Future<bool?> confirmDelete(BuildContext context, String title, String description) => showDialog<bool>(
      context: context,
      barrierColor: AppColors.black40,
      builder: (ctx) => Center(
        child: Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            width: 320,
            padding: const EdgeInsets.all(16),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: AppText.poppins(size: 14, weight: FontWeight.w600)),
              const SizedBox(height: 8),
              Text(description, style: AppText.poppins(size: 12, color: AppColors.gray600)),
              const SizedBox(height: 16),
              Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                GestureDetector(
                  onTap: () => Navigator.of(ctx).pop(false),
                  child: Text('Cancel', style: AppText.poppins(size: 14, color: AppColors.gray600)),
                ),
                const SizedBox(width: 12),
                GestureDetector(
                  onTap: () => Navigator.of(ctx).pop(true),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(color: AppColors.bluntRed, borderRadius: BorderRadius.circular(4)),
                    child: Text('Delete', style: AppText.poppins(size: 14, color: Colors.white)),
                  ),
                ),
              ]),
            ]),
          ),
        ),
      ),
    );
