import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/state/app_state.dart';
import 'features/auth/auth_page.dart';
import 'features/booking/booking_page.dart';
import 'features/booking/cart_checkout_page.dart';
import 'features/enquiry/enquiry_pages.dart';
import 'features/festival/festival_landing_page.dart';
import 'features/home/home_page.dart';
import 'features/pooja/category_index_page.dart';
import 'features/pooja/pooja_detail_page.dart';
import 'features/pooja/pooja_listing_page.dart';
import 'features/static/static_pages.dart';
import 'features/user/address_page.dart';
import 'features/user/cart_wishlist_pages.dart';
import 'features/user/order_detail_page.dart';
import 'features/user/orders_page.dart';
import 'features/user/profile_page.dart';
import 'features/vidya/vidya_pages.dart';

/// Paths equal the website's URLs (pages/**). Static paths are listed before
/// the `/:language/:location/...` patterns so they win.
/// Pages a signed-out user may open; everything else goes to /auth first.
const _publicPaths = {'/auth', '/oauth', '/privacy-policy', '/terms-and-conditions'};

GoRouter buildRouter(WidgetRef ref, Listenable authChanges) {
  GoRoute page(String path, Widget Function(GoRouterState s) builder) =>
      GoRoute(path: path, builder: (context, s) => builder(s));

  return GoRouter(
    initialLocation: '/',
    refreshListenable: authChanges,
    redirect: (context, s) {
      if (_publicPaths.contains(s.uri.path) || isSignedIn(ref.read(authProvider))) return null;
      final from = s.uri.toString();
      return from == '/' ? '/auth' : '/auth?redirect=${Uri.encodeComponent(from)}';
    },
    errorBuilder: (context, s) => const RedirectHome404(),
    routes: [
      page('/', (s) => HomePage(section: s.uri.queryParameters['section'])),

      // pages/oauth — stores the token cookie, then goes home.
      GoRoute(
        path: '/oauth',
        redirect: (context, s) {
          final token = s.uri.queryParameters['token'];
          if (token == null || token.isEmpty) return null;
          ref.read(authProvider.notifier).setToken(token);
          return '/';
        },
        builder: (context, s) => const SizedBox.shrink(),
      ),

      // The website sends this to "/" outside the enquiry subdomain.
      GoRoute(path: '/book-iyer', redirect: (context, s) => '/'),

      page('/auth', (s) => AuthPage(redirect: s.uri.queryParameters['redirect'])),
      page('/booking', (s) => BookingPage(query: s.uri.queryParameters)),
      page(
        '/booking/:slug',
        (s) => CartCheckoutPage(
          cartId: s.pathParameters['slug']!,
          bmpChooseDate: s.uri.queryParameters['bmpChooseDate'] == 'true',
        ),
      ),
      page('/festival/:slug', (s) => FestivalLandingScreen(slug: s.pathParameters['slug']!)),
      page('/vidya', (s) => VidyaIndexPage(page: int.tryParse(s.uri.queryParameters['page'] ?? '') ?? 1)),
      page('/vidya/:slug', (s) => VidyaPostPage(slug: s.pathParameters['slug']!)),

      // pages/user/**
      page('/user', (s) => const ProfilePage()),
      page(
        '/user/profile',
        (s) => ProfilePage(
          phoneVerifiedFalse: s.uri.queryParameters['phoneverified'] == 'false',
          redirectUrl: s.uri.queryParameters['redirecturl'],
        ),
      ),
      page('/user/orders', (s) => const OrdersPage()),
      page('/user/orders/:slug', (s) => OrderDetailPage(orderId: s.pathParameters['slug']!, type: s.uri.queryParameters['type'])),
      page('/user/cart', (s) => const CartPage()),
      page('/user/Wishlist', (s) => const WishlistPage()),
      GoRoute(path: '/user/wishlist', redirect: (context, s) => '/user/Wishlist'),
      page('/user/address', (s) => const AddressPage()),
      page('/user/payment', (s) => const ComingSoonUserPage(text: 'Payments coming soon')),
      page('/user/myActivities', (s) => const ComingSoonUserPage(text: 'Activities coming soon')),
      page('/user/settings', (s) => const SettingsPage()),

      // Static pages.
      page('/about-us', (s) => const AboutUsPage()),
      page('/about-us/testimonies', (s) => const TestimoniesPage()),
      page('/contact-us', (s) => const ContactUsPage()),
      page('/faq', (s) => const FaqPage()),
      page('/privacy-policy', (s) => const PrivacyPolicyPage()),
      page('/terms-and-conditions', (s) => const TermsPage()),
      page('/thank-you', (s) => const ThankYouPage()),

      // pages/enquiry/** (no site chrome).
      page('/enquiry', (s) => const EnquiryPage()),
      page('/enquiry/thank-you', (s) => const ThankYouPage()),
      page('/enquiry/book-iyer', (s) => const EnquiryPage(dataFile: 'book-iyer')),
      page('/enquiry/book-pandit', (s) => const EnquiryPage(dataFile: 'book-pandit')),
      page('/enquiry/book-purohit', (s) => const EnquiryPage(dataFile: 'book-purohit')),
      page('/enquiry/griha-pravesh-pooja', (s) => const EnquiryPage(dataFile: 'griha-pravesh-pooja')),
      page('/enquiry/satyanarayan-pooja', (s) => const EnquiryPage(dataFile: 'satyanarayan-landing')),
      page('/enquiry/shrad-death-rituals', (s) => const EnquiryPage(dataFile: 'shrad-death')),

      // pages/[language]/[location]/** — the bare path redirects home.
      GoRoute(path: '/:language/:location', redirect: (context, s) => '/'),
      page(
        '/:language/:location/pooja',
        (s) => PoojaListingPage(language: s.pathParameters['language']!, location: s.pathParameters['location']!),
      ),
      page(
        '/:language/:location/pooja/:slug',
        (s) => PoojaDetailPage(
          language: s.pathParameters['language']!,
          location: s.pathParameters['location']!,
          slug: s.pathParameters['slug']!,
        ),
      ),
      page(
        '/:language/:location/category',
        (s) => CategoryIndexPage(language: s.pathParameters['language']!, location: s.pathParameters['location']!),
      ),
      page(
        '/:language/:location/category/:slug',
        (s) => PoojaListingPage(
          language: s.pathParameters['language']!,
          location: s.pathParameters['location']!,
          categorySlug: s.pathParameters['slug']!,
        ),
      ),
    ],
  );
}
