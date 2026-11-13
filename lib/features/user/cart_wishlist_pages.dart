import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/bmp_api.dart';
import '../../core/storage/cookies.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/utils/format.dart';
import '../../core/utils/json.dart';
import '../../core/widgets/form_fields.dart';
import '../../core/widgets/site/user_menu.dart';
import '../../core/widgets/site_image.dart';
import '../../core/widgets/toast.dart';
import '../../core/widgets/ui.dart';
import '../address/address_widgets.dart';
import '../pooja/listing_widgets.dart';
import '../pooja/pooja_detail_page.dart';
import 'profile_page.dart';

String _poojaPath(String slug) =>
    '/${Cookies.get('language_name')?.toLowerCase()}/${Cookies.get('location_name')?.toLowerCase()}/pooja/$slug';

// ---------------------------------------------------------------------------
// pages/user/cart.jsx (pooja cart only — the temple cart is out of scope)
// ---------------------------------------------------------------------------

class CartPage extends StatefulWidget {
  const CartPage({super.key});

  @override
  State<CartPage> createState() => _CartPageState();
}

class _CartPageState extends State<CartPage> {
  static const _perPage = 6;
  List<Json> _carts = [];
  int _total = 0;
  int _page = 1;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch({bool showLoader = true}) async {
    if (showLoader) {
      setState(() {
        _carts = [];
        _total = 0;
        _loading = true;
      });
    }
    try {
      final r = await BmpApi.userCart(_page, _perPage);
      final d = obj(r.data);
      if (r.statusCode == 200 && intOf(d['statusCode']) == 200) {
        _carts = objList(d['body']);
        _total = intOf(d['totalCount']);
      } else if (r.statusCode != 200) {
        Toast.error(strOrNull(d['error']) ?? 'Network error occurred');
      }
    } catch (e) {
      Toast.error('An unexpected error occurred');
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _delete(String cartId) async {
    if (Cookies.get('accessToken') == null) {
      goLogin(context);
      return;
    }
    setState(() {
      _carts = _carts.where((c) => str(c['_id']) != cartId).toList();
      _total = (_total - 1).clamp(0, 1 << 30);
    });
    try {
      final r = await BmpApi.removeCartItem(cartId);
      final d = obj(r.data);
      if (r.statusCode == 200 && intOf(d['statusCode']) == 200) {
        Toast.success('Cart item deleted successfully');
      } else {
        Toast.show(str(d['error']));
      }
    } catch (e) {
      Toast.show('Error deleting cart item $e');
    }
    await _fetch(showLoader: false);
  }

  @override
  Widget build(BuildContext context) {
    final nPages = (_total / _perPage).ceil();
    return UserShell(padding: const EdgeInsets.fromLTRB(32 + 24, 40, 32 + 24, 16), children: [
      if (_loading)
        const AppSpinner()
      else ...[
        Text('My Cart ($_total Items)', style: AppText.poppins(weight: FontWeight.w500, color: AppColors.defaultText, height: 1.5)),
        const SizedBox(height: 16),
        AppSelectField<String>(
          value: 'pooja',
          options: const ['pooja'],
          labelOf: (_) => 'Pooja Items Cart',
          radius: 8,
          borderColor: AppColors.bluntRed,
          textStyle: AppText.poppins(size: 14, weight: FontWeight.w500, color: Colors.black),
          onChanged: (_) {},
        ),
        if (_carts.isNotEmpty)
          PaginationBar(
            nPages: nPages,
            currentPage: _page,
            onPageChange: (p) {
              _page = p;
              _fetch();
            },
          ),
        if (_carts.isNotEmpty)
          for (final c in _carts)
            _CartCard(
              cart: c,
              onDelete: () async {
                final ok = await confirmDelete(context, 'Remove Item', 'Are you sure you want to remove this item from your cart?');
                if (ok == true) _delete(str(c['_id']));
              },
              onBook: () => context.push('/booking/${str(c['_id'])}'),
            )
        else
          Padding(
            padding: const EdgeInsets.only(top: 80),
            child: Column(children: [
              Text('No Items found in cart', style: AppText.poppins(size: 20, weight: FontWeight.w500, color: AppColors.red600, height: 1)),
              const SizedBox(height: 4),
              GestureDetector(
                onTap: () => context.push('/${Cookies.get('language_name')}/${Cookies.get('location_name')}/pooja'),
                child: Text.rich(
                  const TextSpan(children: [
                    TextSpan(text: 'Kindly explore '),
                    TextSpan(text: 'POOJA SERVICES', style: TextStyle(color: AppColors.bluntRed, fontWeight: FontWeight.w700)),
                  ]),
                  textAlign: TextAlign.center,
                  style: AppText.poppins(size: 20, weight: FontWeight.w500, color: AppColors.red600),
                ),
              ),
            ]),
          ),
      ],
    ]);
  }
}

class _CartCard extends StatelessWidget {
  const _CartCard({required this.cart, required this.onDelete, required this.onBook});
  final Json cart;
  final VoidCallback onDelete;
  final VoidCallback onBook;

  @override
  Widget build(BuildContext context) {
    final p = obj(pick(cart, ['pooja', 0]));
    if (p.isEmpty) return const SizedBox.shrink();
    final desc = str(p['shortDescription']);
    final type = str(cart['packageType']);
    final pkg = obj(pick(cart, ['packageDetails', type]));
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(16),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.lightGrey)),
      child: Stack(clipBehavior: Clip.none, children: [
        const Positioned(
          right: -20,
          bottom: -16,
          child: SiteImage('/icons/Group6334.svg', width: 60, height: 64, placeholderColor: Colors.transparent),
        ),
        Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 64,
              height: 64,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(color: const Color(0xFF4ADE80), borderRadius: BorderRadius.circular(8)),
              child: SiteImage(strOrNull(pick(p, ['media', 0, 'mediaUrl']))),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Padding(
                  padding: const EdgeInsets.only(right: 20),
                  child: Text(str(p['name']), style: AppText.poppins(size: 14, weight: FontWeight.w600, color: AppColors.defaultText, height: 20 / 14)),
                ),
                Text('${desc.length > 90 ? desc.substring(0, 90) : desc} ${desc.length > 90 ? ' ...' : ''}',
                    style: AppText.poppins(size: 12, color: AppColors.defaultText, height: 20 / 12)),
                Align(
                  alignment: Alignment.centerRight,
                  child: GestureDetector(
                    onTap: () => context.push(_poojaPath(str(p['slug']))),
                    child: Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Text('Know More', style: AppText.poppins(size: 12, weight: FontWeight.w500, color: AppColors.bluntRed)),
                        const SizedBox(width: 8),
                        const SiteImage('/icons/right-arrow.svg', width: 10, height: 10, placeholderColor: Colors.transparent),
                      ]),
                    ),
                  ),
                ),
              ]),
            ),
          ]),
          const SizedBox(height: 16),
          Row(children: [
            Text('Package: ', style: AppText.poppins(size: 12, color: AppColors.defaultText, height: 20 / 12)),
            Text(type.toUpperCase(), style: AppText.poppins(size: 12, weight: FontWeight.w500, color: AppColors.defaultText)),
            GestureDetector(
              onTap: () => context.push(_poojaPath(str(p['slug']))),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text('Change', style: AppText.poppins(size: 12, weight: FontWeight.w500, color: AppColors.bluntRed)),
              ),
            ),
          ]),
          if (cart['packageDetails'] != null)
            Text(
              '${truthy(pkg['numberOfPandits']) ? '${str(pkg['numberOfPandits'])} Pandit' : ''}${truthy(pkg['numberOfDays']) ? ' + ${str(pkg['numberOfDays'])} Day' : ''}',
              style: AppText.poppins(size: 16, color: AppColors.defaultText),
            ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text('₹ ${formatAmountPutComma(pick(cart, ['amounts', 'fullPayment', 'totalAmount']))}',
                style: AppText.poppins(weight: FontWeight.w600, color: AppColors.defaultText)),
          ),
          const SizedBox(height: 12),
          Material(
            color: AppColors.bluntRed,
            borderRadius: BorderRadius.circular(6),
            child: InkWell(
              borderRadius: BorderRadius.circular(6),
              onTap: onBook,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text('Book Now', textAlign: TextAlign.center, style: AppText.poppins(size: 16, weight: FontWeight.w500, color: Colors.white)),
              ),
            ),
          ),
        ]),
        Positioned(
          top: -4,
          right: -4,
          child: GestureDetector(
            onTap: onDelete,
            child: const SiteImage('/icons/Cancelbutton.svg', width: 16, height: 16, placeholderColor: Colors.transparent),
          ),
        ),
      ]),
    );
  }
}

// ---------------------------------------------------------------------------
// pages/user/Wishlist.jsx
// ---------------------------------------------------------------------------

class WishlistPage extends StatefulWidget {
  const WishlistPage({super.key});

  @override
  State<WishlistPage> createState() => _WishlistPageState();
}

class _WishlistPageState extends State<WishlistPage> {
  static const _perPage = 6;
  List<Json> _items = [];
  bool _loading = true;
  int _total = 100;
  int _page = 1;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    try {
      final r = await BmpApi.wishlist(_page, _perPage);
      final d = obj(r.data);
      if (r.statusCode == 200) {
        if (intOf(d['statusCode']) == 200) {
          _items = objList(d['body']);
          _total = intOf(d['totalCount'], _total);
        } else {
          Toast.show('Empty Wishlist');
        }
      } else {
        Toast.show(str(d['error']));
      }
    } catch (_) {
      Toast.error('Error fetching getUserWishlistApi');
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _remove(String id) async {
    try {
      final r = await BmpApi.removeWishlist(id);
      final d = obj(r.data);
      if (r.statusCode == 200 && intOf(d['statusCode']) == 200) {
        Toast.success('Wishlist item removed successfully');
        setState(() => _items = _items.where((w) => str(w['_id']) != id).toList());
      } else {
        Toast.error(str(d['error'], 'Error removing wishlist item'));
      }
    } catch (_) {
      Toast.show('Error removing wishlist item');
    }
  }

  Future<void> _addToCart(Json pooja) async {
    Json? packages;
    try {
      final r = await BmpApi.poojaPackages(str(pooja['packages']));
      final d = obj(r.data);
      if (r.statusCode == 200 && intOf(d['statusCode']) == 200) {
        packages = d;
      } else {
        Toast.show('No Packages available');
      }
    } catch (_) {}
    if (!mounted || packages == null) return;
    final pkg = obj(pick(packages, ['body', 0]));
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      barrierColor: AppColors.black40,
      shape: const RoundedRectangleBorder(),
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.headerQuote))),
            child: Row(children: [
              Expanded(
                child: Text.rich(
                  TextSpan(children: [
                    const TextSpan(text: 'Select the package : '),
                    TextSpan(text: cssCapitalize(str(pooja['slug']).replaceAll('-', ' '))),
                  ]),
                  style: AppText.poppins(size: 20, weight: FontWeight.w500, color: AppColors.bluntRed),
                ),
              ),
              GestureDetector(
                onTap: () => Navigator.of(ctx).pop(),
                child: const SiteImage('/icons/Cancelbutton.svg', width: 20, height: 20, placeholderColor: Colors.transparent),
              ),
            ]),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(24, 48, 24, 48),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              for (final t in const [('basic', 'Basic'), ('standard', 'Standard'), ('premium', 'Premium')])
                if (pkg[t.$1] is Map)
                  PoojaPackageCard(
                    packageData: obj(pkg[t.$1]),
                    packageName: t.$2,
                    onKnowMore: () => showKnowMore(ctx, obj(pkg[t.$1]), t.$2, pooja),
                    onBookNow: () {
                      Navigator.of(ctx).pop();
                      _routeToBooking({'poojaId': str(pooja['_id']), 'packageId': str(pkg['_id']), 'packageType': t.$1});
                    },
                  ),
            ]),
          ),
        ]),
      ),
    );
  }

  Future<void> _routeToBooking(Map<String, String> query) async {
    final token = Cookies.get('accessToken');
    final redirect = '?redirecturl=/user/Wishlist';
    if (token == null) {
      context.push('/auth$redirect');
      Toast.show('Please Login To Book Pooja');
      return;
    }
    try {
      final r = await BmpApi.userDetails(token);
      if (!mounted) return;
      if (r.statusCode == 200) {
        context.push(Uri(path: '/booking', queryParameters: query).toString());
      } else {
        context.push('/auth$redirect');
      }
    } catch (_) {
      if (mounted) context.push('/auth$redirect');
    }
  }

  @override
  Widget build(BuildContext context) {
    final nPages = (_total / _perPage).ceil();
    return UserShell(padding: const EdgeInsets.fromLTRB(32 + 16, 16, 32 + 16, 16), children: [
      if (_loading)
        const AppSpinner()
      else ...[
        Row(children: [
          Expanded(child: Text('My Wishlist (${_items.length})', style: AppText.poppins(weight: FontWeight.w500, color: AppColors.defaultText, height: 1.5))),
        ]),
        PaginationBar(
          nPages: nPages,
          currentPage: _page,
          onPageChange: (p) {
            setState(() {
              _page = p;
              _loading = true;
            });
            _fetch();
          },
        ),
        if (_items.isNotEmpty)
          for (final w in _items) _wishCard(w)
        else
          Column(children: [
            Text('No wishlist items', style: AppText.poppins(size: 20, weight: FontWeight.w500, color: AppColors.red600, height: 1.4)),
            GestureDetector(
              onTap: () => context.push('/${Cookies.get('language_name')}/${Cookies.get('location_name')}/pooja'),
              child: Text.rich(
                const TextSpan(children: [
                  TextSpan(text: 'Kindly explore '),
                  TextSpan(text: ' POOJA SERVICES', style: TextStyle(color: AppColors.bluntRed, fontWeight: FontWeight.w700)),
                ]),
                textAlign: TextAlign.center,
                style: AppText.poppins(size: 20, weight: FontWeight.w500, color: AppColors.red600),
              ),
            ),
          ]),
      ],
    ]);
  }

  Widget _wishCard(Json w) {
    final p = obj(pick(w, ['pooja', 0]));
    final desc = str(p['shortDescription']);
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.profileBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.lightGrey),
      ),
      child: Stack(clipBehavior: Clip.none, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 64,
            height: 64,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(color: AppColors.black40, borderRadius: BorderRadius.circular(8)),
            child: SiteImage(strOrNull(pick(p, ['media', 0, 'mediaUrl'])) ?? '/images/aigenerated/Deities.jpeg'),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Padding(
                padding: const EdgeInsets.only(right: 20),
                child: Text(str(p['name']), style: AppText.poppins(size: 14, weight: FontWeight.w600, color: AppColors.defaultText, height: 20 / 14)),
              ),
              Text('${desc.length > 90 ? desc.substring(0, 90) : desc} ${desc.length > 90 ? ' ...' : ''}',
                  style: AppText.poppins(size: 12, color: AppColors.defaultText, height: 20 / 12)),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(children: [
                  const StarRow(rating: 3),
                  const SizedBox(width: 8),
                  Text.rich(
                    const TextSpan(children: [
                      TextSpan(text: 'reviews'),
                      TextSpan(text: ' 1.2k', style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.defaultText)),
                    ]),
                    style: AppText.poppins(size: 12, color: AppColors.slate400),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => context.push('/${Cookies.get('language_name')}/${Cookies.get('location_name')}/pooja/${str(p['slug'])}'),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Text('Know More', style: AppText.poppins(size: 12, weight: FontWeight.w500, color: AppColors.bluntRed)),
                      const SizedBox(width: 8),
                      const SiteImage('/icons/right-arrow.svg', width: 10, height: 10, placeholderColor: Colors.transparent),
                    ]),
                  ),
                ]),
              ),
              Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Expanded(
                  child: Text('₹ ${str(p['price'])}', style: AppText.poppins(weight: FontWeight.w600, color: AppColors.defaultText)),
                ),
                GestureDetector(
                  onTap: () => _addToCart(p),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0x4D8A1C23))),
                    child: Text('ADD TO CART', style: AppText.poppins(size: 14, weight: FontWeight.w500, color: AppColors.bluntRed)),
                  ),
                ),
              ]),
            ]),
          ),
        ]),
        Positioned(
          top: -4,
          right: -4,
          child: GestureDetector(
            onTap: () => _remove(str(w['_id'])),
            child: const SiteImage('/icons/Cancelbutton.svg', width: 16, height: 16, placeholderColor: Colors.transparent),
          ),
        ),
      ]),
    );
  }
}
