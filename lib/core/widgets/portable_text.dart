import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../config.dart';
import '../theme/app_text.dart';
import '../utils/json.dart';
import '../utils/launch.dart';

/// Per-style text for [PortableTextView] (the website's `components.block`).
class PortableStyles {
  const PortableStyles({
    required this.normal,
    this.headings = const {},
    this.blockSpacing = const {},
    this.listIndent = 24,
    this.listGap = 8,
    this.linkColor = const Color(0xFF2563EB),
    this.strongColor,
    this.blockquote,
    this.h2Border,
  });

  final TextStyle normal;
  final Map<String, TextStyle> headings;

  /// (top, bottom) margins per block style.
  final Map<String, (double, double)> blockSpacing;
  final double listIndent;
  final double listGap;
  final Color linkColor;
  final Color? strongColor;
  final TextStyle? blockquote;

  /// `border-l-4 border-orange-500 pl-4` on h2 in blog posts.
  final Color? h2Border;
}

/// Renders Sanity Portable Text blocks (`@portabletext/react`).
class PortableTextView extends StatelessWidget {
  const PortableTextView({super.key, required this.blocks, required this.styles, this.maxLines});
  final List<dynamic> blocks;
  final PortableStyles styles;
  final int? maxLines;

  @override
  Widget build(BuildContext context) {
    final items = objList(blocks);
    final children = <Widget>[];
    var i = 0;
    while (i < items.length) {
      final b = items[i];
      final listType = strOrNull(b['listItem']);
      if (listType != null) {
        final group = <Json>[];
        while (i < items.length && strOrNull(items[i]['listItem']) == listType) {
          group.add(items[i]);
          i++;
        }
        children.add(Padding(
          padding: EdgeInsets.symmetric(vertical: styles.listGap * 3),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            for (var n = 0; n < group.length; n++)
              Padding(
                padding: EdgeInsets.only(left: styles.listIndent - 16, bottom: styles.listGap),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  SizedBox(width: 24, child: Text(listType == 'number' ? '${n + 1}.' : '•', style: styles.normal)),
                  Expanded(child: Text.rich(_spans(group[n], styles.normal), style: styles.normal)),
                ]),
              ),
          ]),
        ));
        continue;
      }
      if (str(b['_type']) == 'block') {
        final style = str(b['style'], 'normal');
        final ts = style == 'blockquote' ? (styles.blockquote ?? styles.normal) : (styles.headings[style] ?? styles.normal);
        final (top, bottom) = styles.blockSpacing[style] ?? (0.0, 0.0);
        Widget text = Text.rich(_spans(b, ts), style: ts, maxLines: maxLines, overflow: maxLines != null ? TextOverflow.ellipsis : null);
        if (style == 'h2' && styles.h2Border != null) {
          text = Container(
            padding: const EdgeInsets.only(left: 16),
            decoration: BoxDecoration(border: Border(left: BorderSide(color: styles.h2Border!, width: 4))),
            child: text,
          );
        }
        if (style == 'blockquote') {
          text = Container(
            padding: const EdgeInsets.fromLTRB(24, 16, 16, 16),
            decoration: const BoxDecoration(
              color: Color(0xFFFFF7ED),
              border: Border(left: BorderSide(color: Color(0xFFFB923C), width: 4)),
            ),
            child: text,
          );
        }
        children.add(Padding(padding: EdgeInsets.only(top: top, bottom: bottom), child: text));
      }
      i++;
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children);
  }

  TextSpan _spans(Json block, TextStyle base) {
    final defs = {for (final d in objList(block['markDefs'])) str(d['_key']): d};
    return TextSpan(children: [
      for (final c in objList(block['children']))
        () {
          var s = const TextStyle();
          GestureRecognizer? tap;
          for (final m in list(c['marks']).map((e) => '$e')) {
            switch (m) {
              case 'strong':
                s = s.copyWith(fontWeight: FontWeight.w600, color: styles.strongColor);
              case 'em':
                s = s.copyWith(fontStyle: FontStyle.italic);
              case 'code':
                s = s.copyWith(fontFamily: 'monospace', color: const Color(0xFFDC2626), backgroundColor: const Color(0xFFF3F4F6));
              case 'underline':
                s = s.copyWith(decoration: TextDecoration.underline);
              default:
                final def = defs[m];
                if (def != null && str(def['_type']) == 'link') {
                  s = s.copyWith(color: styles.linkColor, decoration: TextDecoration.underline, decorationColor: styles.linkColor);
                  final href = str(def['href']);
                  tap = TapGestureRecognizer()..onTap = () => openExternal(href);
                }
            }
          }
          return TextSpan(text: str(c['text']), style: s, recognizer: tap);
        }(),
    ]);
  }
}

/// `toProxiedUrl(urlFor(image).quality(80).url())` from sanity-client.
String? sanityImageUrl(dynamic image, {int quality = 80}) {
  final ref = str(pick(image, ['asset', '_ref']));
  final m = RegExp(r'^image-([a-zA-Z0-9]+)-(\d+x\d+)-(\w+)$').firstMatch(ref);
  if (m == null) return null;
  final url = 'https://cdn.sanity.io/images/${AppConfig.sanityProjectId}/production/${m.group(1)}-${m.group(2)}.${m.group(3)}?q=$quality';
  return AppConfig.api('/image-proxy?url=${Uri.encodeComponent(url)}');
}

/// Default text style for blog post body copy.
TextStyle blogBody() => AppText.poppins(size: 16, color: const Color(0xFF374151), height: 1.625, letterSpacing: .4);
