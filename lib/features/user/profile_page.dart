import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/api/api_client.dart';
import '../../core/api/bmp_api.dart';
import '../../core/state/app_state.dart';
import '../../core/storage/cookies.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/utils/json.dart';
import '../../core/widgets/fieldset.dart';
import '../../core/widgets/site/app_drawer.dart';
import '../../core/widgets/site/site_page.dart';
import '../../core/widgets/site/user_menu.dart';
import '../../core/widgets/site_image.dart';
import '../../core/widgets/toast.dart';
import '../../core/widgets/ui.dart';
import '../../core/widgets/native.dart';

/// `/user/*` pages sit in V2CommonLayout's `container mx-auto` (2rem gutter).
class UserShell extends StatelessWidget {
  const UserShell({super.key, required this.children, this.padding = const EdgeInsets.symmetric(horizontal: 32)});
  final List<Widget> children;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) => SitePage(
        isUserRoute: true,
        children: [Padding(padding: padding, child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children))],
      );
}

/// pages/user/profile/index.jsx (+ /user, which renders the same page).
class ProfilePage extends ConsumerStatefulWidget {
  const ProfilePage({super.key, this.phoneVerifiedFalse = false, this.redirectUrl});
  final bool phoneVerifiedFalse;
  final String? redirectUrl;

  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<ProfilePage> {
  Json? _user;
  bool _loading = true;

  /// The photo uploaded in this visit, shown until the page is left.
  XFile? _uploaded;

  @override
  void initState() {
    super.initState();
    _check();
    if (widget.phoneVerifiedFalse) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Toast.show('Verify Your Mobile Number Before Booking');
        _openModal('Phone');
      });
    }
  }

  Future<void> _check() async {
    final token = Cookies.get('accessToken');
    try {
      if (token != null) {
        final r = await BmpApi.userDetails(token);
        if (r.statusCode == 200 && mounted) setState(() => _user = obj(obj(r.data)['body']));
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        Cookies.remove('accessToken');
        if (mounted) goLogin(context);
      }
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _updateUser(Json data) async {
    try {
      final r = await BmpApi.updateUser(data);
      final d = obj(r.data);
      if (r.statusCode == 201) {
        if (intOf(d['statusCode']) == 200) {
          Toast.success(str(d['message']));
          if (d['body'] is String) Cookies.set('accessToken', d['body'] as String);
          if (widget.phoneVerifiedFalse && mounted) {
            Future.delayed(const Duration(milliseconds: 100), () {
              if (mounted) context.push('/${widget.redirectUrl ?? ''}');
            });
          }
        } else {
          Toast.error(str(d['error']));
        }
      } else {
        Toast.error(str(d['body']));
      }
    } catch (_) {
      Toast.error('Something went wrong');
    } finally {
      setState(() => _loading = false);
      Future.delayed(const Duration(milliseconds: 100), _check);
      ref.invalidate(authProvider);
    }
  }

  /// Returns whether the upload succeeded, so the modal can stay open on failure.
  Future<bool> _updateImage(XFile file) async {
    try {
      final form = FormData.fromMap({'file': await MultipartFile.fromFile(file.path, filename: file.name)});
      final r = await BmpApi.uploadProfileImage(form);
      final d = obj(r.data);
      if (r.statusCode == 201 && intOf(d['statusCode']) == 200) {
        Toast.success(str(d['message']));
        // Show the new photo right away, and drop the old one from the image
        // caches: the backend stores every upload under the same path
        // (`profile-image/scaled_<id>.jpg`), which is also the cache key.
        final old = strOrNull(_user?['profileImage']);
        if (old != null && old.startsWith('http')) {
          final url = SiteImage.resolve(old);
          await CachedNetworkImage.evictFromCache(url, cacheKey: SiteImage.cacheKeyFor(url));
        }
        PaintingBinding.instance.imageCache
          ..clear()
          ..clearLiveImages();
        if (mounted) setState(() => _uploaded = file);
        _check();
        ref.invalidate(authProvider);
        return true;
      }
      debugPrint('PROFILE IMAGE UPLOAD FAILED: ${r.statusCode} ${r.data}');
      Toast.error(strOrNull(d['error']) ?? strOrNull(d['message']) ?? 'Could not upload the photo');
    } catch (e) {
      debugPrint('PROFILE IMAGE UPLOAD ERROR: $e');
      if (e is DioException) debugPrint('BODY: ${e.response?.data}');
      Toast.error(apiErrorMessage(e, 'Could not upload the photo'));
    }
    return false;
  }

  void _openModal(String heading) {
    showDialog(
      context: context,
      barrierColor: AppColors.black40,
      builder: (_) => _ProfileUpdateModal(
        heading: heading,
        user: _user,
        currentFile: _uploaded,
        verifying: widget.phoneVerifiedFalse,
        onSave: (key, value) {
          if (value.replaceAll(' ', '').isNotEmpty) _updateUser({key: value});
        },
        onImage: _updateImage,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final u = _user;
    Widget row(String label, String? value, String heading, {bool capitalize = false}) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(label, style: AppText.poppins(size: 12, color: AppColors.headerQuote)),
                  const SizedBox(height: 8),
                  Text(
                    capitalize && (value ?? '').isNotEmpty ? '${value![0].toUpperCase()}${value.substring(1)}' : (value ?? ''),
                    style: AppText.poppins(size: 14, color: AppColors.defaultText, height: 20 / 14),
                  ),
                ]),
              ),
            ),
            GestureDetector(
              onTap: () => _openModal(heading),
              child: const SiteImage('/icons/edit.svg', width: 16, height: 16, placeholderColor: Colors.transparent),
            ),
          ]),
        );
    Widget card(String title, List<Widget> children, {double titleGap = 0}) => Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.profileBg,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0x268993AC)),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(title, style: AppText.poppins(size: 16, weight: FontWeight.w500, color: AppColors.defaultText, height: 1.5)),
            SizedBox(height: titleGap),
            ...children,
          ]),
        );

    return UserShell(padding: EdgeInsets.zero, children: [
      if (_loading)
        const Padding(padding: EdgeInsets.symmetric(vertical: 80), child: AppSpinner())
      else ...[
        const SizedBox(height: 48),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: card('Basic Information', [
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Row(children: [
                Expanded(child: Text('Profile Picture', style: AppText.poppins(size: 12, color: AppColors.headerQuote))),
                Semantics(
                  button: true,
                  label: 'Edit profile picture',
                  child: GestureDetector(
                    onTap: () => _openModal('Profile Image'),
                    child: _ProfileAvatar(url: strOrNull(u?['profileImage']), file: _uploaded, size: 56, showEdit: true),
                  ),
                ),
              ]),
            ),
            const Divider(height: 1),
            row('Name', str(u?['userName']), 'Name'),
            const Divider(height: 1),
            row('D.O.B.', str(u?['dob']), 'DOB'),
            const Divider(height: 1),
            row('Gender', str(u?['gender']), 'Gender', capitalize: true),
            const Divider(height: 1),
            const SizedBox(height: 8),
            InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () async {
                if (await confirmLogout(context)) ref.read(authProvider.notifier).logout();
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Row(children: [
                  const Icon(LucideIcons.logOut, size: 18, color: AppColors.destructive),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text('Log out',
                        style: AppText.poppins(size: 14, weight: FontWeight.w500, color: AppColors.destructive)),
                  ),
                  const Icon(LucideIcons.chevronRight, size: 16, color: AppColors.headerQuote),
                ]),
              ),
            ),
          ]),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: card('Contact Information', [
            const Divider(height: 1),
            row('Phone', str(u?['phone']), 'Phone'),
            const Divider(height: 1),
            row('Email', str(u?['email']), 'Email'),
          ], titleGap: 16),
        ),
        const SizedBox(height: 16),
      ],
    ]);
  }
}

/// Round profile photo: a just-picked/uploaded local [file] wins over the
/// server [url]; falls back to the account icon when there's neither or the
/// URL fails to load. [showEdit] adds the pen badge.
class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar({this.url, this.file, this.size = 56, this.showEdit = false});
  final String? url;
  final XFile? file;
  final double size;
  final bool showEdit;

  @override
  Widget build(BuildContext context) {
    final px = (size * MediaQuery.devicePixelRatioOf(context)).ceil();
    const fallback = SiteImage('/icons/acount.svg', placeholderColor: Colors.transparent);
    final f = file;
    final u = url;
    Widget image;
    if (f != null) {
      image = Image.file(File(f.path), fit: BoxFit.cover, cacheWidth: px);
    } else if (u == null || u.isEmpty) {
      image = fallback;
    } else {
      final resolved = SiteImage.resolve(u);
      if (resolved.startsWith('http')) {
        image = CachedNetworkImage(
          imageUrl: resolved,
          cacheKey: SiteImage.cacheKeyFor(resolved),
          fit: BoxFit.cover,
          memCacheWidth: px,
          placeholder: (_, _) => const SizedBox.shrink(),
          errorWidget: (_, _, e) {
            // Path only: the query string of a presigned URL is a credential.
            debugPrint('PROFILE IMAGE LOAD FAILED: ${resolved.split('?').first} -> $e');
            return fallback;
          },
        );
      } else if (resolved.startsWith('assets/')) {
        image = SiteImage(u, placeholderColor: Colors.transparent);
      } else {
        debugPrint('PROFILE IMAGE: not a full URL, cannot load "$u"');
        image = fallback;
      }
    }

    final badge = size * .36;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: size,
            height: size,
            clipBehavior: Clip.antiAlias,
            decoration: const BoxDecoration(color: Color(0xFFBFDBFE), shape: BoxShape.circle),
            child: image,
          ),
          if (showEdit)
            Positioned(
              right: -2,
              bottom: -2,
              child: Container(
                width: badge,
                height: badge,
                decoration: BoxDecoration(
                  color: AppColors.bluntRed,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: Icon(LucideIcons.pencil, size: badge * .5, color: Colors.white),
              ),
            ),
        ],
      ),
    );
  }
}

class _ProfileUpdateModal extends StatefulWidget {
  const _ProfileUpdateModal({
    required this.heading,
    required this.user,
    required this.verifying,
    required this.onSave,
    required this.onImage,
    this.currentFile,
  });
  final String heading;
  final Json? user;
  final bool verifying;
  final void Function(String key, String value) onSave;
  final Future<bool> Function(XFile file) onImage;

  /// A photo already uploaded in this visit, previewed before a new pick.
  final XFile? currentFile;

  @override
  State<_ProfileUpdateModal> createState() => _ProfileUpdateModalState();
}

class _ProfileUpdateModalState extends State<_ProfileUpdateModal> {
  String? _value;
  XFile? _image;
  bool _saving = false;

  Future<void> _pickImage() async {
    // Resized on the device: a 12 MP camera photo is a slow upload for a
    // picture shown at 56 px.
    final f = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 1024, maxHeight: 1024, imageQuality: 85);
    if (f != null && mounted) setState(() => _image = f);
  }

  String get _key => switch (widget.heading) {
        'Profile Image' => 'file',
        'Name' => 'userName',
        'DOB' => 'dob',
        'Gender' => 'gender',
        'Phone' => 'phone',
        'Email' => 'email',
        _ => '',
      };

  Future<void> _submit() async {
    if (_saving) return;
    final v = _value;
    if (_key.isNotEmpty && _key != 'file' && v != null && v.replaceFirst(' ', '').isNotEmpty) widget.onSave(_key, v);
    final image = _image;
    if (widget.heading == 'Profile Image') {
      if (image == null) {
        Toast.show('Please choose a photo');
        return;
      }
      setState(() => _saving = true);
      final ok = await widget.onImage(image);
      if (!mounted) return;
      if (!ok) {
        setState(() => _saving = false);
        return;
      }
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final u = widget.user;
    Widget field() {
      switch (widget.heading) {
        case 'Profile Image':
          return Column(mainAxisSize: MainAxisSize.min, children: [
            const SizedBox(height: 8),
            Semantics(
              button: true,
              label: 'Choose profile picture',
              child: GestureDetector(
                onTap: _saving ? null : _pickImage,
                child: _ProfileAvatar(
                  url: strOrNull(u?['profileImage']),
                  file: _image ?? widget.currentFile,
                  size: 120,
                  showEdit: true,
                ),
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _saving ? null : _pickImage,
              icon: const Icon(LucideIcons.imagePlus, size: 16),
              label: Text(_image == null ? 'Choose photo' : 'Change photo', style: AppText.poppins(size: 13, weight: FontWeight.w500)),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.bluntRed,
                side: const BorderSide(color: AppColors.lightGrey),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _image == null ? 'Tap the photo to pick one from your gallery' : 'Preview — tap SAVE to upload',
              textAlign: TextAlign.center,
              style: AppText.poppins(size: 12, color: AppColors.headerQuote),
            ),
          ]);
        case 'Gender':
          final current = _value ?? str(u?['gender']);
          return InputDecorator(
            decoration: fieldsetDecoration('Gender *'),
            child: GestureDetector(
              onTap: () async {
                final v = await showPickerSheet<String>(context,
                    title: 'Gender', options: const ['male', 'female', 'others'], labelOf: (v) => '${v[0].toUpperCase()}${v.substring(1)}');
                if (v != null) setState(() => _value = v);
              },
              child: Text(
                current.isEmpty ? 'Gender' : '${current[0].toUpperCase()}${current.substring(1)}',
                style: AppText.poppins(size: 14, color: AppColors.defaultText.withValues(alpha: .5)),
              ),
            ),
          );
        case 'DOB':
          return InputDecorator(
            decoration: fieldsetDecoration('Date of birth (dd/mm/yy)'),
            child: GestureDetector(
              onTap: () async {
                final d = await showNativeDatePicker(context, initialDate: DateTime(2000), firstDate: DateTime(1900), lastDate: DateTime.now());
                if (d != null) setState(() => _value = DateFormat('yyyy-MM-dd').format(d));
              },
              child: Text(_value ?? (strOrNull(u?['dob']) ?? 'Date of birth'), style: AppText.poppins(size: 14, color: AppColors.defaultText)),
            ),
          );
        default:
          final (label, initial, type) = switch (widget.heading) {
            'Name' => ('Name *', str(u?['userName']), TextInputType.name),
            'Phone' => ('Phone', str(u?['phone']), TextInputType.number),
            _ => ('Email', str(u?['email']), TextInputType.emailAddress),
          };
          return TextFormField(
            initialValue: initial,
            keyboardType: type,
            onChanged: (v) => _value = v,
            style: AppText.poppins(size: 14, color: AppColors.defaultText),
            decoration: fieldsetDecoration(label, hint: label, prefix: fieldsetIcon(null)),
          );
      }
    }

    Widget btn(String label, bool primary, VoidCallback onTap) => Expanded(
          child: GestureDetector(
            onTap: _saving ? null : onTap,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                color: primary ? AppColors.bluntRed.withValues(alpha: _saving ? .6 : 1) : Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.lightGrey),
              ),
              child: primary && _saving
                  ? const Center(
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      ),
                    )
                  : Text(label,
                      textAlign: TextAlign.center,
                      style: AppText.sans(size: 12, color: primary ? Colors.white : AppColors.defaultText, letterSpacing: 1.2, height: 1.33)),
            ),
          ),
        );

    return Dialog(
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.all(28),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('${widget.verifying ? 'Verify ' : 'Edit '}${widget.heading}',
              style: AppText.sans(size: 20, weight: FontWeight.w500, height: 1.4)),
          const SizedBox(height: 12),
          field(),
          const SizedBox(height: 28),
          const Divider(height: 1),
          const SizedBox(height: 16),
          Row(children: [btn('CANCEL', false, () => Navigator.of(context).pop()), const SizedBox(width: 8), btn('SAVE', true, _submit)]),
        ]),
      ),
    );
  }
}

/// pages/user/settings.jsx
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) => UserShell(padding: const EdgeInsets.symmetric(horizontal: 32 + 24), children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Text('Notification Settings', style: AppText.poppins(weight: FontWeight.w500, color: AppColors.defaultText)),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Text('Coming Soon !!', style: AppText.poppins(weight: FontWeight.w500, color: AppColors.defaultText)),
        ),
      ]);
}

/// pages/user/payment.jsx and myActivities.jsx ("coming soon").
class ComingSoonUserPage extends StatelessWidget {
  const ComingSoonUserPage({super.key, required this.text});
  final String text;

  @override
  Widget build(BuildContext context) => UserShell(children: [
        Text(text, textAlign: TextAlign.center, style: AppText.poppins(size: 30, weight: FontWeight.w600, color: AppColors.bluntRed)),
      ]);
}
