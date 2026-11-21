import 'package:bmp_app/core/utils/ritual_steps.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses bold lead-ins, plain sentences and indented sub-items', () {
    const html = '<p>Intro</p>'
        '<h3>Rituals Performed in the Puja</h3>'
        '<ul>'
        '<li><strong>Ganesh Puja</strong> – Removes obstacles before the puja.</li>'
        '<li><strong>Kalash Sthapana:</strong> Invoking the deities</li>'
        '<li>Havan – Offering to the sacred fire</li>'
        '<li class="ql-indent-1"><strong>Navagraha Havan</strong></li>'
        '<li class="ql-indent-1">Lakshmi Havan</li>'
        '<li>The family offers <strong>aarti</strong> together.</li>'
        '</ul>'
        '<h3>Benefits</h3><ul><li>Not a step</li></ul>';
    final steps = extractRitualSteps(html)!;
    expect(steps.length, 4);
    expect(steps[0].title, 'Ganesh Puja');
    expect(steps[0].text, 'Removes obstacles before the puja');
    expect(steps[1].title, 'Kalash Sthapana');
    expect(steps[1].text, 'Invoking the deities');
    expect(steps[2].title, 'Havan');
    expect(steps[2].sub.map((s) => s.title.isNotEmpty ? s.title : s.text), ['Navagraha Havan', 'Lakshmi Havan']);
    expect(steps[3].title, '');
    expect(steps[3].text, 'The family offers aarti together');
  });

  test('returns null without a ritual heading or with under 3 steps', () {
    expect(extractRitualSteps('<h3>About</h3><ul><li>a</li><li>b</li><li>c</li></ul>'), isNull);
    expect(extractRitualSteps('<h3>Puja Vidhi</h3><ul><li>a</li><li>b</li></ul>'), isNull);
    expect(extractRitualSteps(null), isNull);
  });
}
