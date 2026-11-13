import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vector_graphics_compiler/vector_graphics_compiler.dart';

/// flutter_svg rejects some SVG features (per-glyph x lists, `font-size="none"`)
/// at runtime; parse every bundled SVG here so a bad export fails fast.
void main() {
  final files = Directory('assets').listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.svg')).toList();

  for (final f in files) {
    test(f.path, () {
      expect(() => encodeSvg(xml: f.readAsStringSync(), debugName: f.path, enableClippingOptimizer: false, enableMaskingOptimizer: false, enableOverdrawOptimizer: false), returnsNormally);
    });
  }
}
