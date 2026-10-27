import 'package:flutter_test/flutter_test.dart';
import 'package:ibd_mobile/core/skill/local_skill_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// T3：本地 Skill 缓存可读/可清理/可失效回归。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('save → load 往返：含 formatVersion 与规则', () async {
    await LocalSkillStore.saveFromConfirmed(
      hospital: '某三甲医院A',
      reportType: '血常规',
      items: [
        {'nameNorm': '白细胞计数', 'nameRaw': 'WBC', 'unit': '10^9/L'},
      ],
    );
    final loaded = await LocalSkillStore.load('某三甲医院A', '血常规');
    expect(loaded, isNotNull);
    expect(loaded!['formatVersion'], LocalSkillStore.formatVersion);
    expect(loaded['version'], 1);
    final items = loaded['items'] as List;
    expect(items, hasLength(1));
    expect((items.first as Map)['name'], '白细胞计数');
    expect((items.first as Map)['pattern'], contains('白细胞计数'));
  });

  test('同院同型再次确认：version 递增', () async {
    for (var i = 0; i < 2; i++) {
      await LocalSkillStore.saveFromConfirmed(
        hospital: '医院B',
        reportType: '肝功',
        items: [
          {'nameNorm': '白蛋白', 'unit': 'g/L'},
        ],
      );
    }
    final loaded = await LocalSkillStore.load('医院B', '肝功');
    expect(loaded!['version'], 2);
  });

  test('失效：旧缓存无 formatVersion → load 返回 null', () async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(
      LocalSkillStore.key('旧医院', '血常规'),
      '{"hospital":"旧医院","items":[]}',
    );
    expect(await LocalSkillStore.load('旧医院', '血常规'), isNull);
  });

  test('失效：损坏 JSON → load 返回 null', () async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(LocalSkillStore.key('坏医院', '血常规'), '{broken');
    expect(await LocalSkillStore.load('坏医院', '血常规'), isNull);
  });

  test('clear 删除目标缓存，不影响其它', () async {
    await LocalSkillStore.saveFromConfirmed(
      hospital: '医院C',
      reportType: '血常规',
      items: [
        {'nameNorm': '白细胞计数'},
      ],
    );
    await LocalSkillStore.saveFromConfirmed(
      hospital: '医院D',
      reportType: '血常规',
      items: [
        {'nameNorm': '白细胞计数'},
      ],
    );
    await LocalSkillStore.clear('医院C', '血常规');
    expect(await LocalSkillStore.load('医院C', '血常规'), isNull);
    expect(await LocalSkillStore.load('医院D', '血常规'), isNotNull);
    expect(await LocalSkillStore.count(), 1);
  });

  test('clearAll 清空全部 Skill 缓存但保留其它键', () async {
    await LocalSkillStore.saveFromConfirmed(
      hospital: '医院E',
      reportType: '血常规',
      items: [
        {'nameNorm': '白细胞计数'},
      ],
    );
    final sp = await SharedPreferences.getInstance();
    await sp.setString('unrelated_key', 'keep');
    await LocalSkillStore.clearAll();
    expect(await LocalSkillStore.count(), 0);
    expect(sp.getString('unrelated_key'), 'keep');
  });
}
