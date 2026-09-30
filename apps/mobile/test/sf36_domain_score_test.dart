import 'package:flutter_test/flutter_test.dart';

import 'package:ibd_mobile/core/survey/sf36_scoring.dart';

void main() {
  test('36 题映射：每题入 0 或 1 个域，变化题不入域，8 域题数合计 35', () {
    final counts = <String, int>{};
    final seen = <int>{};
    for (final entry in Sf36Domains.byId.entries) {
      counts[entry.key] = entry.value.length;
      for (final i in entry.value) {
        expect(seen.add(i), isTrue, reason: 'index $i mapped twice');
      }
    }
    expect(Sf36Domains.byId.length, 8);
    expect(counts['gh'], 1);
    expect(counts['pf'], 8);
    expect(counts['rp'], 5);
    expect(counts['bp'], 2);
    expect(counts['vt'], 4);
    expect(counts['sf'], 5);
    expect(counts['re'], 5);
    expect(counts['mh'], 5);
    expect(seen.contains(Sf36Domains.changeItemIndex), isFalse);
    expect(seen.length, 35);
  });

  test('全 0 → 域 0；全 4 → 域 100', () {
    final zeros = List<int>.filled(36, 0);
    final fours = List<int>.filled(36, 4);
    for (final key in Sf36Domains.byId.keys) {
      expect(Sf36Scoring.scoreDomain(key, zeros), 0);
      expect(Sf36Scoring.scoreDomain(key, fours), 100);
    }
  });

  test('混合值按 round(100*sum/(4*n)) 计分', () {
    // bp: indices 18,19 — values 4 and 2 → sum=6, n=2 → 100*6/8 = 75
    final scores = List<int>.filled(36, 0);
    scores[18] = 4;
    scores[19] = 2;
    expect(Sf36Scoring.scoreDomain('bp', scores), 75);

    // gh: index 0 only — value 3 → 100*3/4 = 75
    scores[0] = 3;
    expect(Sf36Scoring.scoreDomain('gh', scores), 75);

    // rounding: pf n=8, sum=3 → 100*3/32 = 9.375 → 9
    final pfScores = List<int>.filled(36, 0);
    pfScores[2] = 3;
    expect(Sf36Scoring.scoreDomain('pf', pfScores), 9);
  });

  test('scoreAll 返回 8 域与 stdAverage（算术均四舍五入）', () {
    final scores = List<int>.filled(36, 4);
    // 使各域不同：gh=0（索引0），bp 全 0（18,19）
    scores[0] = 0;
    scores[18] = 0;
    scores[19] = 0;
    final result = Sf36Scoring.scoreAll(scores);
    expect(result.domains.length, 8);
    expect(result.domains['gh'], 0);
    expect(result.domains['bp'], 0);
    expect(result.domains['pf'], 100);
    // mean = (0+100+100+100+0+100+100+100)/8 = 75
    expect(result.stdAverage, 75);
  });

  test('简化合计为 36 题之和（含变化题）', () {
    final scores = List<int>.filled(36, 1);
    scores[1] = 4;
    expect(Sf36Scoring.simplifiedTotal(scores), 35 + 4);
  });

  test('题数不足抛 ArgumentError', () {
    expect(
      () => Sf36Scoring.scoreDomain('pf', List<int>.filled(5, 0)),
      throwsArgumentError,
    );
  });
}
