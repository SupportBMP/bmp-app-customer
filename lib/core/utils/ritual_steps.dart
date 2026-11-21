/// Port of bmp_fe utils/ritualSteps.js — pulls the ritual steps out of a
/// pooja's description HTML (admin-authored Quill output) for the timeline.
///
/// Finds the first heading mentioning Ritual / Vidhi / Procedure / Steps /
/// What happens, then reads the <ul>/<ol> lists after it until the next
/// heading. Each <li> is a step: a bold lead-in followed by "–", "-" or ":"
/// is the title and the rest the line under it; anything else stays one
/// sentence. Indented items (ql-indent-*) become sub-steps of the step above.
/// Returns null for fewer than 3 steps.
library;

import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;

class RitualStep {
  RitualStep(this.title, this.text, [List<RitualStep>? sub]) : sub = sub ?? [];
  final String title;
  final String text;
  final List<RitualStep> sub;
}

final _heading = RegExp(r'^h[1-6]$', caseSensitive: false);
final _ritualHeading = RegExp(r'(ritual|vidhi|procedure|steps|what happens)', caseSensitive: false);
const _maxSteps = 10;
const _maxTitle = 60;
final _sep = RegExp(r'^\s*[–—:-]');

String _clean(String s) =>
    s.replaceAll(RegExp(r'\s+'), ' ').replaceAll('&amp;', '&').replaceAll('&nbsp;', ' ').replaceAll(' ', ' ').trim();

RitualStep _splitItem(dom.Element li) {
  final full = _clean(li.text).replaceFirst(RegExp(r'\.$'), '');
  final strong = li.querySelector('strong, b');
  final lead = strong == null ? '' : _clean(strong.text).replaceFirst(RegExp(r'[.:–—-]+$'), '').trim();

  // 1. Bold lead-in at the very start, followed by a separator (or nothing).
  if (lead.isNotEmpty && lead.length <= _maxTitle && full.startsWith(lead)) {
    final rest = full.substring(lead.length);
    if (rest.trim().isEmpty || _sep.hasMatch(rest)) {
      return RitualStep(lead, _clean(rest.replaceFirst(RegExp(r'^[\s–—:.-]+'), '')));
    }
  }
  // 2. "Short title – line" written in plain text.
  final m = RegExp(r'^([^–—:]{2,60}?)\s+[–—:-]\s+(.+)$').firstMatch(full);
  if (m != null) return RitualStep(m.group(1)!.trim(), m.group(2)!.trim());

  // 3. Just a sentence.
  return RitualStep('', full);
}

List<RitualStep>? extractRitualSteps(String? html) {
  if (html == null || html.trim().isEmpty) return null;
  try {
    final nodes = html_parser.parseFragment(html).children;
    final start = nodes.indexWhere((n) => _heading.hasMatch(n.localName ?? '') && _ritualHeading.hasMatch(n.text));
    if (start == -1) return null;

    final steps = <RitualStep>[];
    for (var i = start + 1; i < nodes.length; i++) {
      final node = nodes[i];
      final tag = node.localName ?? '';
      if (_heading.hasMatch(tag)) break;
      if (tag != 'ul' && tag != 'ol') continue;
      for (final li in node.querySelectorAll('li')) {
        final item = _splitItem(li);
        if (item.title.isEmpty && item.text.isEmpty) continue;
        final indented = RegExp(r'ql-indent-\d').hasMatch(li.attributes['class'] ?? '');
        if (indented && steps.isNotEmpty) {
          steps.last.sub.add(item);
        } else {
          steps.add(item);
        }
      }
    }
    final trimmed = steps.take(_maxSteps).toList();
    return trimmed.length >= 3 ? trimmed : null;
  } catch (_) {
    return null;
  }
}
