import 'package:dio/dio.dart';

import '../config.dart';
import '../storage/cookies.dart';
import 'api_client.dart';

/// Port of the in-scope functions in bmp_fe/pages/api/index.js.
/// Temple, ecommerce and admin endpoints are intentionally left out.
class BmpApi {
  BmpApi._();

  static ApiClient get _c => ApiClient.instance;
  static String? get _token => Cookies.get('accessToken');
  static String _u(String path) => AppConfig.api(path);

  /// `createPoojaQuery` — note the website repeats each key (`&k=v&k`).
  static String createPoojaQuery(Map<String, dynamic> query) {
    final b = StringBuffer();
    query.forEach((k, v) => b.write('&$k=$v&$k'));
    return b.toString();
  }

  // ---- Global / home ------------------------------------------------------

  static Future<Response> homeV2({String location = '', String language = ''}) =>
      _c.get(_u('/pooja-global/home-v2?location=$location&language=$language'));

  static Future<Response> header({String? location, String? language}) {
    var url = _u('/pooja-global/header?');
    if (location != null && location.isNotEmpty) url += '&location=$location&';
    if (language != null && language.isNotEmpty) url += '&language=$language&';
    return _c.get(url);
  }

  static Future<Response> footer() => _c.get(_u('/pooja-global/footer'));

  static Future<Response> allLocations() => _c.get(_u('/pooja-locations?page=0&pageSize=100'));

  static Future<Response> allLanguages([int? status]) {
    var q = '?page=0&pageSize=100';
    if (status != null) q += '&status=$status';
    return _c.get(_u('/pooja-languages$q'));
  }

  static Future<Response> geoLocation(double lat, double long) =>
      _c.get(_u('/pooja-locations/l1?lat=$lat&long=$long'));

  static Future<Response> pageSeo(String pageId) => _c.get(_u('pooja-seo?pageid=$pageId'));

  static Future<Response> singleSeoByItem(String query) => _c.get(_u('pooja-seo$query'));

  // ---- Poojas -------------------------------------------------------------

  static Future<Response> searchPooja(String text, String? locationId, String? languageId) {
    final language = languageId ?? Cookies.get('language');
    return _c.get(_u('/pooja/find?t=${Uri.encodeQueryComponent(text)}&language=$language&location=$locationId'));
  }

  static Future<Response> singlePooja(String slug, [Map<String, dynamic>? extraQuery]) {
    var url = _u('/pooja?slug=$slug&slug');
    if (extraQuery != null) url += createPoojaQuery(extraQuery);
    return _c.get(url);
  }

  static Future<Response> allPoojaItems(
    Map<String, dynamic> routerQuery, {
    int currentPage = 1,
    int recordsPerPage = 10,
    String sort = 'name',
    int sortOrder = 1,
  }) {
    final page = '?page=${currentPage - 1}&pageSize=$recordsPerPage&sort=$sort&sortOrder=$sortOrder';
    return _c.get(_u('/pooja$page${createPoojaQuery(routerQuery)}'));
  }

  static Future<Response> poojaPackages(String packageId, {bool ePooja = false}) =>
      _c.get(_u('/pooja-packages/$packageId${ePooja ? '?type-of-pooja=e-pooja' : ''}'));

  static Future<Response> resolvePoojaPackageMap(String poojaId, String? locationId, String? languageId) =>
      _c.get(_u('pooja-package-map/resolve?poojaId=$poojaId&locationId=$locationId&languageId=$languageId'));

  static Future<Response> poojaFaqItems(List<String> faqIds, {bool isEPooja = false}) {
    var q = '?';
    for (final id in faqIds) {
      q += 'ids=$id&';
    }
    if (isEPooja) q += 'pooja-type=e-pooja&';
    return _c.get(_u('/pooja-faq?$q'));
  }

  static Future<Response> allFaqs() => _c.get(_u('/pooja-faq?pageSize=100'));

  static Future<Response> customForm(String poojaPath) =>
      _c.get(_u('/pooja/custom-forms?pooja-path=$poojaPath'));

  static Future<Response> additionalOfferings(String poojaId) =>
      _c.get(_u('/pooja-ecommerce/pooja/$poojaId'));

  static Future<Response> additionalItemsByServiceId(String id) =>
      _c.get(_u('/additional-items?serviceId=$id'));

  static Future<Response> availableSlots(String query) =>
      _c.get(_u('/pooja-slot-restrictions/available-slots$query'));

  static Future<Response> slotRestrictions(String query) =>
      _c.get(_u('pooja-slot-restrictions$query'));

  static Future<Response> allCategories() => _c.get(_u('/categories'));

  static Future<Response> subcategoriesOf(String categoryId) =>
      _c.get(_u('/categories/subcategories?categoryName=$categoryId'));

  static Future<Response> allSubcategories([String query = '']) =>
      _c.get(_u('/categories/subcategories$query'));

  // ---- Reviews / testimonials --------------------------------------------

  static Future<Response> poojaReviews(String poojaId, int currentPage, int recordsPerPage) =>
      _c.get(_u('/pooja-reviews/$poojaId?page=${currentPage - 1}&pageSize=$recordsPerPage&sort=createdAt'));

  static Future<Response> createPoojaReview(String poojaId, String comment, num rating) =>
      _c.post(_u('/pooja-reviews'), {'poojaId': poojaId, 'comment': comment, 'rating': rating}, _token);

  static Future<Response> testimonials(int currentPage, int recordsPerPage) =>
      _c.get(_u('/testimonials/?page=${currentPage - 1}&pageSize=$recordsPerPage'));

  // ---- Blogs (vidya) ------------------------------------------------------

  static Future<Response> blogBySlug(String slug) => _c.get(_u('blogs?slug=$slug'));

  static Future<Response> allBlogs(int page, int pageSize, [String expand = 'all']) =>
      _c.get(_u('blogs?page=$page&pageSize=$pageSize&expand=$expand'));

  // ---- Auth -------------------------------------------------------------

  /// Goes through the website's same-origin relay, which adds the HMAC
  /// signature BMP_BE requires on `/auth/otp/send`.
  static Future<Response> sendPhoneOtp(String phone) =>
      _c.post('${AppConfig.siteUrl}/api/auth/send-otp', {'phone': phone});

  static Future<Response> sendEmailOtp(String email) =>
      _c.post(_u('/auth/email/send-otp'), {'email': email});

  static Future<Response> verifyEmailOtp(String email, String otp, String? accessToken) =>
      _c.post(_u('/auth/email/verify-otp'), {'email': email, 'otp': otp}, accessToken);

  static Future<Response> verifyPhoneOtp(
    String phone,
    String otp,
    String? accessToken, {
    String? cartId,
    String? guestUserId,
  }) =>
      _c.post(
        _u('/auth/otp/verify'),
        {
          'phone': phone,
          'otp': otp,
          'cartId': ?cartId,
          'guestUserId': ?guestUserId,
        },
        accessToken,
      );

  static Future<Response> guestLogin() => _c.post(_u('/auth/guest-login'), {}, '');

  static Future<Response> userDetails([String? accessToken]) =>
      _c.getAuth(_u('/auth'), accessToken ?? _token);

  static Future<Response> updateUser(Map<String, dynamic> data) =>
      _c.post(_u('/pooja-users/update'), data, _token);

  static Future<Response> uploadProfileImage(FormData data) =>
      _c.postFiles(_u('/pooja-users/profile-image'), data, _token);

  // ---- Address ----------------------------------------------------------

  static Future<Response> userAddresses() => _c.getAuth(_u('/pooja-users/address'), _token);

  static Future<Response> addAddress(Map<String, dynamic> data) =>
      _c.post(_u('/pooja-users/address'), data, _token);

  static Future<Response> updateAddress(String addressId, Map<String, dynamic> data) =>
      _c.patch(_u('/pooja-users/address/$addressId'), data, _token);

  static Future<Response> removeAddress(String addressId) =>
      _c.delete(_u('/pooja-users/address/$addressId'), _token);

  // ---- Wishlist -----------------------------------------------------------

  static Future<Response> wishlist(int currentPage, int recordsPerPage) => _c.getAuth(
        _u('/pooja-wishlist?page=${currentPage - 1}&pageSize=$recordsPerPage&sort=createdAt'),
        _token,
      );

  static Future<Response> addToWishlist(Map<String, dynamic> data) =>
      _c.post(_u('/pooja-wishlist'), data, _token);

  static Future<Response> removeWishlist(String wishlistId) =>
      _c.delete(_u('/pooja-wishlist/$wishlistId'), _token);

  // ---- Cart -------------------------------------------------------------

  static Future<Response> userCart(int currentPage, int recordsPerPage) => _c.getAuth(
        _u('/pooja-cart?page=${currentPage - 1}&pageSize=$recordsPerPage'),
        _token,
      );

  static Future<Response> cartIdByPoojaId(String poojaId) =>
      _c.getAuth(_u('/pooja-cart/?poojaId=$poojaId'), _token);

  static Future<Response> addToCart(Map<String, dynamic> data, [String? accessToken]) =>
      _c.post(_u('/pooja-cart'), data, accessToken ?? _token);

  static Future<Response> updateCart(String cartId, Map<String, dynamic> body, [String? accessToken]) =>
      _c.patch(_u('/pooja-cart/$cartId'), body, accessToken ?? _token);

  static Future<Response> removeCartItem(String cartId) =>
      _c.delete(_u('/pooja-cart/$cartId'), _token);

  // ---- Coupons -------------------------------------------------------------

  static Future<Response> validateCoupon(Map<String, dynamic> body, [String? accessToken]) =>
      _c.post(_u('coupons/validate'), body, accessToken ?? _token);

  static Future<Response> applyCouponToCart(String cartId, Map<String, dynamic> body, [String? accessToken]) =>
      _c.post(_u('pooja-cart/$cartId/payment-method'), body, accessToken ?? _token);

  static Future<Response> removeCouponFromCart(String cartId, Map<String, dynamic> body, [String? accessToken]) =>
      _c.delete(_u('pooja-cart/$cartId/payment-method'), accessToken ?? _token, body);

  static Future<Response> couponById(String couponId, [String? accessToken]) =>
      _c.getAuth(_u('coupons/$couponId'), accessToken ?? _token);

  static Future<Response> coupons([String query = '']) => _c.getAuth(_u('coupons$query'), _token);

  // ---- Orders / payment ---------------------------------------------------

  static Future<Response> createPaymentOrder({
    required String receipt,
    required String cartId,
    required dynamic type,
    required dynamic amount,
    dynamic extraDetailsByUser,
    dynamic address,
  }) =>
      _c.post(
        _u('/orders'),
        {
          'cartId': cartId,
          'paymentType': type,
          'amount': amount,
          'extraDetailsByUser': extraDetailsByUser,
          'address': address,
          'receipt': receipt,
        },
        _token,
      );

  /// `createPaymentOrder(receipt)` for an order's remaining balance — the
  /// website sends only the receipt (other fields are undefined).
  static Future<Response> createRemainingPaymentOrder(String receipt) =>
      _c.post(_u('/orders'), {'receipt': receipt}, _token);

  static Future<Response> verifyPayment({
    required String razorPayPaymentId,
    required String razorPayOrderId,
    required String razorPaySignature,
    String? cartId,
    required String orderId,
  }) =>
      _c.post(
        _u('/orders/verify'),
        {
          'razorPayOrderId': razorPayOrderId,
          'razorPayPaymentId': razorPayPaymentId,
          'razorPaySignature': razorPaySignature,
          'cartId': ?cartId,
          'orderId': orderId,
        },
        _token,
      );

  static Future<Response> allOrders(int currentPage, int recordsPerPage, {int orderType = 1}) => _c.getAuth(
        _u('/orders/user/?page=${currentPage - 1}&pageSize=$recordsPerPage&sort=createdAt&orderType=$orderType'),
        _token,
      );

  static Future<Response> orderById(String orderId) => _c.getAuth(_u('/orders/user/$orderId'), _token);

  static Future<Response> updateOrder(String orderId, Map<String, dynamic> data) =>
      _c.patch(_u('/orders/$orderId'), data, _token);

  // ---- Leads / enquiries --------------------------------------------------

  /// `POST /pooja-leads` (sent with the user's token when signed in).
  static Future<Response> postEnquiry(Map<String, dynamic> data) => _c.post(_u('pooja-leads'), data, _token);

  static Future<Response> postGlobalLeadCapture(Map<String, dynamic> data) =>
      _c.postWithHeaders(_u('/pooja-leads/crm/generic'), data, {});

  // ---- Festival experience ---------------------------------------------

  static Future<Response> festivalExperience(String query) =>
      _c.get(_u('festival-experience$query'));
}
