import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../config.dart';
import '../theme/app_colors.dart';

/// Port of ImageWrapper: renders a website `public/` path (`/images/x.png`,
/// bundled under `assets/`) or a remote URL, with S3 → CloudFront rewrite.
class SiteImage extends StatelessWidget {
  const SiteImage(
    this.src, {
    super.key,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.alignment = Alignment.center,
    this.color,
    this.borderRadius,
    this.placeholderColor = AppColors.muted,
  });

  final String? src;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Alignment alignment;
  final Color? color;
  final BorderRadius? borderRadius;
  final Color placeholderColor;

  static const _s3Host = 'bmpassets.s3.ap-south-1.amazonaws.com';
  static const _cdnHost = 'ddm054vpoxu9.cloudfront.net';

  /// Maps `/images/a.png` → `assets/images/a.png` and leaves URLs alone.
  ///
  /// Public S3 URLs move to CloudFront, but a presigned one (private files
  /// like profile photos) must stay on S3: its signature covers the host, so
  /// rewriting it makes S3 answer 403.
  static String resolve(String src) {
    if (src.startsWith('http')) return isPresigned(src) ? src : src.replaceAll(_s3Host, _cdnHost);
    if (src.startsWith('//')) return 'https:$src';
    if (src.startsWith('/')) return 'assets${Uri.decodeFull(src)}';
    return src;
  }

  static bool isPresigned(String url) => url.contains('X-Amz-Signature=');

  /// The image cache key for [url]. A presigned URL gets a new signature on
  /// every fetch of the user, so keying on the full URL would re-download
  /// (and flash) the same photo each time; the path alone identifies it.
  static String? cacheKeyFor(String url) => isPresigned(url) ? url.split('?').first : null;

  /// Pixel width to decode a raster image at, so a 2000 px photo shown in a
  /// 64 px box isn't decoded (and held in memory) at full size — decoding
  /// those while they scroll into view is what drops frames.
  ///
  /// The box is never wider than the screen, so an unbounded [width] falls
  /// back to the screen width. For [BoxFit.cover] / [BoxFit.fitHeight] the
  /// image may be scaled by the box height instead, so the larger side is
  /// used. [BoxFit.none] / [BoxFit.scaleDown] depend on the native size and
  /// are left alone. Never upscales: a smaller source decodes as-is.
  int? _decodeWidth(BuildContext context) {
    if (fit == BoxFit.none || fit == BoxFit.scaleDown) return null;
    final w = width;
    final h = height;
    final screen = MediaQuery.sizeOf(context).width;
    final boxW = w != null && w.isFinite ? w : screen;
    final boxH = h != null && h.isFinite ? h : 0.0;
    final logical = fit == BoxFit.cover || fit == BoxFit.fitHeight ? (boxW > boxH ? boxW : boxH) : boxW;
    if (logical <= 0) return null;
    return (logical * MediaQuery.devicePixelRatioOf(context)).ceil();
  }

  @override
  Widget build(BuildContext context) {
    final s = src;
    Widget child;
    if (s == null || s.isEmpty) {
      child = _placeholder();
    } else {
      final r = resolve(s);
      final isSvg = r.toLowerCase().split('?').first.endsWith('.svg') || r.contains('/svg?');
      if (r.startsWith('http')) {
        child = isSvg
            ? SvgPicture.network(r, width: width, height: height, fit: fit, alignment: alignment,
                colorFilter: color == null ? null : ColorFilter.mode(color!, BlendMode.srcIn))
            : CachedNetworkImage(
                imageUrl: r,
                cacheKey: cacheKeyFor(r),
                width: width,
                height: height,
                fit: fit,
                alignment: alignment,
                color: color,
                memCacheWidth: _decodeWidth(context),
                fadeInDuration: const Duration(milliseconds: 150),
                placeholder: (_, _) => _placeholder(),
                errorWidget: (_, _, _) => _placeholder(),
              );
      } else if (r.startsWith('assets/')) {
        child = isSvg
            ? SvgPicture.asset(r, width: width, height: height, fit: fit, alignment: alignment,
                colorFilter: color == null ? null : ColorFilter.mode(color!, BlendMode.srcIn))
            : Image.asset(r, width: width, height: height, fit: fit, alignment: alignment, color: color,
                cacheWidth: _decodeWidth(context),
                errorBuilder: (_, _, _) => _remoteFallback(context, s));
      } else {
        child = _placeholder();
      }
    }
    if (borderRadius != null) child = ClipRRect(borderRadius: borderRadius!, child: child);
    return child;
  }

  /// An asset the app didn't bundle still exists on the website.
  Widget _remoteFallback(BuildContext context, String path) => CachedNetworkImage(
        imageUrl: '${AppConfig.siteUrl}$path',
        width: width,
        height: height,
        fit: fit,
        alignment: alignment,
        memCacheWidth: _decodeWidth(context),
        errorWidget: (_, _, _) => _placeholder(),
      );

  Widget _placeholder() => Container(width: width, height: height, color: placeholderColor);
}
