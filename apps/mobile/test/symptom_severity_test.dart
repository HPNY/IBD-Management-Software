import 'package:flutter_test/flutter_test.dart';
import 'package:ibd_mobile/core/checkin/diary_severity.dart';

void main() {
  group('diarySeverity', () {
    test('全空 → 0', () {
      expect(diarySeverity(), 0);
    });

    test('痛10 + 腹泻10 + obvious → clamp 到 10', () {
      expect(
        diarySeverity(
          painLevel: 10,
          bowelCount: 10,
          bloodyStool: 'obvious',
        ),
        10,
      );
    });

    test('pain=6, bowel=5, trace', () {
      // 6*0.5 + 5*0.3 + 1.5 = 3+1.5+1.5 = 6.0
      expect(
        diarySeverity(painLevel: 6, bowelCount: 5, bloodyStool: 'trace'),
        closeTo(6.0, 1e-9),
      );
    });

    test('无 bowelCount 时回落 diarrheaCount', () {
      // 0 + 4*0.3 + 0 = 1.2
      expect(diarySeverity(diarrheaCount: 4), closeTo(1.2, 1e-9));
    });

    test('便血 none/未知档 → 0 血点', () {
      expect(
        diarySeverity(painLevel: 2, bowelCount: 0, bloodyStool: 'none'),
        closeTo(1.0, 1e-9),
      );
      expect(
        diarySeverity(painLevel: 2, bowelCount: 0, bloodyStool: 'weird'),
        closeTo(1.0, 1e-9),
      );
    });
  });

  group('severityBand', () {
    test('分档边界（0–3 绿 · 4–6 黄 · 7–10 红，左闭右开）', () {
      expect(severityBand(0), 'green');
      expect(severityBand(3), 'green');
      expect(severityBand(3.9), 'green');
      expect(severityBand(4), 'warning');
      expect(severityBand(6.9), 'warning');
      expect(severityBand(7), 'danger');
      expect(severityBand(10), 'danger');
    });
  });
}
