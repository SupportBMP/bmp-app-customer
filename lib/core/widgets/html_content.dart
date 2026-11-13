import 'package:flutter/material.dart';
import 'package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart';

import '../theme/app_text.dart';
import '../utils/launch.dart';

/// Renders CMS HTML the way `parse(parsePoojaDescriptionRawHTML(html))`
/// styles it on the website (utils/utils.jsx): headings get `pt-6 leading-7`,
/// paragraphs `text-sm leading-5 py-2`, lists are disc/decimal with
/// `pl-5`, and `<strong>` becomes `font-semibold`.
class PoojaHtml extends StatelessWidget {
  const PoojaHtml(this.html, {super.key, this.fontSize = 14, this.color = const Color(0xFF475569), this.textAlign});
  final String? html;
  final double fontSize;
  final Color color;
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) {
    final h = html;
    if (h == null || h.isEmpty) return const SizedBox.shrink();
    return HtmlWidget(
      h,
      textStyle: AppText.poppins(size: fontSize, color: color, height: 20 / 14, letterSpacing: .3),
      customStylesBuilder: (e) {
        switch (e.localName) {
          case 'h1':
          case 'h2':
          case 'h3':
          case 'h4':
          case 'h5':
          case 'h6':
            return {'padding-top': '24px', 'line-height': '28px', 'font-size': '${fontSize + 2}px', 'margin': '0'};
          case 'p':
            return {
              'padding': '8px 0',
              'margin': '0',
              'line-height': '20px',
              if (textAlign == TextAlign.justify) 'text-align': 'justify',
            };
          case 'strong':
          case 'b':
            return {'font-weight': '600'};
          case 'ul':
            return {'list-style-type': 'disc', 'padding-left': '20px', 'margin': '0'};
          case 'ol':
            return {'list-style-type': 'decimal', 'padding-left': '20px', 'margin': '0'};
          case 'li':
            return {'padding': '4px 0', 'line-height': '20px'};
          case 'a':
            return {'color': '#8A1C23', 'text-decoration': 'underline'};
        }
        return null;
      },
      onTapUrl: (url) {
        openExternal(url);
        return true;
      },
    );
  }
}

/// Plain CMS HTML (blogs, policy pages) with the browser's default styles.
class SimpleHtml extends StatelessWidget {
  const SimpleHtml(this.html, {super.key, this.style, this.styles});
  final String? html;
  final TextStyle? style;
  final Map<String, String>? Function(dynamic element)? styles;

  @override
  Widget build(BuildContext context) {
    if (html == null || html!.isEmpty) return const SizedBox.shrink();
    return HtmlWidget(
      html!,
      textStyle: style ?? AppText.poppins(size: 14, color: const Color(0xFF475569)),
      customStylesBuilder: styles == null ? null : (e) => styles!(e),
      onTapUrl: (url) {
        openExternal(url);
        return true;
      },
    );
  }
}
