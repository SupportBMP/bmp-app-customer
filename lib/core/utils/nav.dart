import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import 'launch.dart';

/// Follows a website href inside the app: site paths go through go_router
/// (routes equal the website's URLs), `tel:` / `mailto:` / `http(s):` open
/// externally, and `#id` scrolls to a [SectionAnchors] section.
void goHref(BuildContext context, String? href) {
  if (href == null || href.isEmpty) return;
  if (href.startsWith('#')) {
    SectionAnchors.maybeOf(context)?.scrollTo(href.substring(1));
    return;
  }
  if (href.startsWith('tel:') || href.startsWith('mailto:') || href.startsWith('http')) {
    if (href.startsWith('https://bookmypoojaonline.com/') || href.startsWith('https://www.bookmypoojaonline.com/')) {
      final path = Uri.parse(href).path;
      if (path.isNotEmpty) {
        context.push(path);
        return;
      }
    }
    openExternal(href);
    return;
  }
  final path = href.startsWith('/') ? href : '/$href';
  context.push(path);
}

/// Page-level registry of scroll targets, the app's version of
/// `document.getElementById(id)` + `scrollToSection`. Stateful so the
/// registered keys survive the page rebuilding.
class SectionAnchors extends StatefulWidget {
  const SectionAnchors({super.key, required this.child});
  final Widget child;

  static SectionAnchorsState? maybeOf(BuildContext context) => context.findAncestorStateOfType<SectionAnchorsState>();

  @override
  State<SectionAnchors> createState() => SectionAnchorsState();
}

class SectionAnchorsState extends State<SectionAnchors> {
  final Map<String, GlobalKey> _keys = {};

  GlobalKey keyFor(String id) => _keys.putIfAbsent(id, () => GlobalKey(debugLabel: 'section:$id'));

  Future<void> scrollTo(String id, {double alignment = 0.0}) async {
    var ctx = _keys[id]?.currentContext;
    // Lazily built slivers only create a section once it nears the viewport,
    // so page down through the page's scroll view until the target exists.
    final position = ctx == null ? _primaryPosition() : null;
    if (position != null) {
      // The target may be above or below; search from the top.
      position.jumpTo(0);
      await WidgetsBinding.instance.endOfFrame;
      ctx = _keys[id]?.currentContext;
      while (ctx == null && position.pixels < position.maxScrollExtent) {
        position.jumpTo((position.pixels + position.viewportDimension).clamp(0.0, position.maxScrollExtent));
        await WidgetsBinding.instance.endOfFrame;
        ctx = _keys[id]?.currentContext;
      }
    }
    if (ctx == null || !ctx.mounted) return;
    await Scrollable.ensureVisible(
      ctx,
      duration: const Duration(milliseconds: 800),
      curve: Curves.easeInOutCubic,
      alignment: alignment,
    );
  }

  /// The first vertical scroll view inside this page.
  ScrollPosition? _primaryPosition() {
    ScrollPosition? found;
    void visit(Element e) {
      if (found != null) return;
      if (e is StatefulElement && e.state is ScrollableState) {
        final p = (e.state as ScrollableState).position;
        if (p.axis == Axis.vertical) {
          found = p;
          return;
        }
      }
      e.visitChildElements(visit);
    }

    (context as Element).visitChildElements(visit);
    return found;
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Wraps a section so `#id` links can reach it.
class Anchor extends StatelessWidget {
  const Anchor(this.id, {super.key, required this.child});
  final String id;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final anchors = SectionAnchors.maybeOf(context);
    if (anchors == null) return child;
    return KeyedSubtree(key: anchors.keyFor(id), child: child);
  }
}
