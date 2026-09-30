/// D1：IBD 相关食物词典与食谱参考（本地静态，非处方建议）。
library;

class FoodDictItem {
  const FoodDictItem({
    required this.label,
    required this.category,
    this.note,
  });

  final String label;
  final String category;

  /// 通俗备注，如「高纤维」「乳制品」
  final String? note;
}

class DietRecipe {
  const DietRecipe({
    required this.title,
    required this.tags,
    this.description,
  });

  final String title;
  final List<String> tags;
  final String? description;
}

/// 常见标签词典（可点选，落入 food_logs）。
const kFoodDictionary = <FoodDictItem>[
  FoodDictItem(label: '牛奶', category: '乳制品', note: '乳糖不耐可减量'),
  FoodDictItem(label: '酸奶', category: '乳制品', note: '部分人耐受较好'),
  FoodDictItem(label: '奶酪', category: '乳制品'),
  FoodDictItem(label: '鸡蛋', category: '蛋白'),
  FoodDictItem(label: '鸡胸肉', category: '蛋白'),
  FoodDictItem(label: '鱼肉', category: '蛋白'),
  FoodDictItem(label: '豆腐', category: '蛋白'),
  FoodDictItem(label: '米饭', category: '主食'),
  FoodDictItem(label: '面条', category: '主食'),
  FoodDictItem(label: '白面包', category: '主食', note: '低渣参考'),
  FoodDictItem(label: '燕麦', category: '主食', note: '高纤维'),
  FoodDictItem(label: '红薯', category: '主食', note: '高纤维'),
  FoodDictItem(label: '西兰花', category: '蔬菜', note: '高纤维'),
  FoodDictItem(label: '胡萝卜', category: '蔬菜'),
  FoodDictItem(label: '南瓜', category: '蔬菜'),
  FoodDictItem(label: '菠菜', category: '蔬菜'),
  FoodDictItem(label: '苹果', category: '水果'),
  FoodDictItem(label: '香蕉', category: '水果'),
  FoodDictItem(label: '西瓜', category: '水果'),
  FoodDictItem(label: '辣火锅', category: '刺激', note: '辛辣'),
  FoodDictItem(label: '油炸食品', category: '刺激', note: '高脂'),
  FoodDictItem(label: '冷饮', category: '刺激'),
  FoodDictItem(label: '咖啡', category: '刺激', note: '咖啡因'),
  FoodDictItem(label: '酒精', category: '刺激'),
  FoodDictItem(label: '坚果', category: '其他', note: '高纤维'),
];

/// 食谱参考卡（一键记入今日标签，非处方）。
const kDietRecipes = <DietRecipe>[
  DietRecipe(
    title: '温和低渣参考',
    description: '发作期常见低渣思路，个体差异大，请与医生/营养师讨论。',
    tags: ['白面包', '米饭', '鸡胸肉', '鱼肉', '香蕉'],
  ),
  DietRecipe(
    title: '乳制品减量',
    description: '若乳糖不耐可尝试减量或换酸奶/无乳糖。',
    tags: ['酸奶', '鸡蛋', '米饭'],
  ),
  DietRecipe(
    title: '刺激食物提醒',
    description: '记录后观察与腹泻/便血关联，不等于必须避免。',
    tags: ['辣火锅', '冷饮', '咖啡', '油炸食品'],
  ),
];

/// 从词典中筛选（label/category 含 q）。
List<FoodDictItem> searchFoodDict(String? q) {
  if (q == null || q.trim().isEmpty) return kFoodDictionary;
  final s = q.trim();
  return kFoodDictionary
      .where(
        (e) => e.label.contains(s) || e.category.contains(s),
      )
      .toList();
}
