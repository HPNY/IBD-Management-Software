import 'package:flutter_test/flutter_test.dart';
import 'package:ibd_mobile/core/food/food_dictionary.dart';
import 'package:ibd_mobile/core/food/food_nutrition.dart';

void main() {
  test('searchFoodDict 按标签/类别筛选', () {
    expect(searchFoodDict('牛奶').first.label, '牛奶');
    expect(searchFoodDict('乳制品').every((e) => e.category == '乳制品'), isTrue);
    expect(searchFoodDict(null).length, kFoodDictionary.length);
    expect(searchFoodDict(''), isNotEmpty);
  });

  test('summarizeDay 相加；全 null 无数据', () {
    final rows = [
      const FoodNutritionRow(date: '2026-09-01', calories: 300, proteinG: 10),
      const FoodNutritionRow(date: '2026-09-01', calories: 200, proteinG: 5),
      const FoodNutritionRow(date: '2026-09-01', foods: ['牛奶']),
      const FoodNutritionRow(date: '2026-09-02', foods: ['米饭']),
    ];
    final s1 = summarizeDay('2026-09-01', rows);
    expect(s1.calories, 500);
    expect(s1.proteinG, 15);
    expect(s1.hasData, isTrue);
    expect(s1.entryCount, 3);
    final s2 = summarizeDay('2026-09-02', rows);
    expect(s2.hasData, isFalse);
    expect(s2.calories, 0);
  });

  test('averageRecent 仅计有数据日', () {
    final rows = [
      const FoodNutritionRow(date: '2026-09-01', calories: 100, proteinG: 4),
      const FoodNutritionRow(date: '2026-09-03', calories: 300, proteinG: 8),
    ];
    final avg = averageRecent(rows, '2026-09-03', 3);
    expect(avg.daysWithKcal, 2);
    expect(avg.avgKcal, 200);
    expect(avg.avgProtein, 6);
  });

  test('mergeFoodTags 去重并入食谱标签', () {
    expect(
      mergeFoodTags('牛奶、鸡蛋', ['牛奶', '米饭']),
      '牛奶、鸡蛋、米饭',
    );
    expect(mergeFoodTags(null, ['香蕉']), '香蕉');
    expect(mergeFoodTags('牛奶', ['  ', '']), '牛奶');
  });
}
