import 'package:flutter_test/flutter_test.dart';
import 'package:ibd_mobile/core/food/food_stool_link.dart';

void main() {
  test('parseFoodTags 拆分并去空', () {
    expect(parseFoodTags('牛奶、辣火锅, 冷饮'), ['牛奶', '辣火锅', '冷饮']);
    expect(parseFoodTags('  ,  ,, '), isEmpty);
    expect(parseFoodTags(null), isEmpty);
  });

  test('foodStoolLinks：吃过日 vs 未吃日腹泻率差（daysEaten≥3 才标可疑）', () {
    // 1/1、1/3 吃牛奶+腹泻；1/5 吃牛奶+腹泻；1/2、1/4 未吃+正常
    final foods = [
      const FoodLogEntry(date: '2026-01-01', tags: ['牛奶']),
      const FoodLogEntry(date: '2026-01-03', tags: ['牛奶', '冷饮']),
      const FoodLogEntry(date: '2026-01-05', tags: ['牛奶']),
    ];
    final stool = {
      '2026-01-01': const StoolDay(diarrheaCount: 4, stoolType: 6),
      '2026-01-02': const StoolDay(diarrheaCount: 1, stoolType: 4),
      '2026-01-03': const StoolDay(
        diarrheaCount: 5,
        stoolType: 7,
        bloodyStool: 'trace',
      ),
      '2026-01-04': const StoolDay(diarrheaCount: 1, stoolType: 4),
      '2026-01-05': const StoolDay(diarrheaCount: 4, stoolType: 6),
    };
    final links = foodStoolLinks(foods: foods, stoolByDate: stool);
    expect(links.length, 2);
    final milk = links.firstWhere((e) => e.tag == '牛奶');
    expect(milk.daysEaten, 3);
    // 当日或昨日吃过牛奶：1/1(吃) 1/2(昨) 1/3(吃) 1/4(昨) 1/5(吃) → 全是 eaten
    // 对照池为空 → base 0；腹泻日 1/1、1/3、1/5 → 3/5
    expect(milk.diarrheaRateBase, 0);
    expect(milk.diarrheaRateEaten, closeTo(3 / 5, 0.001));
    expect(milk.suspiciousDiarrhea, isTrue);

    final cold = links.firstWhere((e) => e.tag == '冷饮');
    expect(cold.daysEaten, 1);
    expect(cold.suspiciousDiarrhea, isFalse); // daysEaten < 3
  });

  test('blood：trace/obvious 计入，none 不计', () {
    const d1 = StoolDay(bloodyStool: 'none');
    const d2 = StoolDay(bloodyStool: 'trace');
    const d3 = StoolDay(bloodyStool: 'obvious');
    expect(d1.hasBlood, isFalse);
    expect(d2.hasBlood, isTrue);
    expect(d3.hasBlood, isTrue);
    expect(const StoolDay(stoolType: 6).isDiarrhea, isTrue);
    expect(const StoolDay(diarrheaCount: 2).isDiarrhea, isFalse);
  });

  test('无食物时返回空列表', () {
    expect(
      foodStoolLinks(
        foods: const [],
        stoolByDate: {'2026-01-01': const StoolDay(diarrheaCount: 1)},
      ),
      isEmpty,
    );
  });
}
