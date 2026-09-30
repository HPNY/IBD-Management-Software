import 'package:flutter_test/flutter_test.dart';
import 'package:ibd_mobile/core/geo/geo_profile.dart';

void main() {
  test('GeoProfile 公开 JSON 仅昵称+城市', () {
    const p = GeoProfile(nickname: '阿豆', city: '杭州');
    final j = p.toPublicJson();
    expect(j.keys.toSet(), {'nickname', 'city'});
    assertNoPreciseLocation(j);
  });

  test('assertNoPreciseLocation 拒绝经纬度/地址', () {
    expect(() => assertNoPreciseLocation({'city': '杭州'}), returnsNormally);
    expect(
      () => assertNoPreciseLocation({'city': '杭州', 'lat': '30.2'}),
      throwsStateError,
    );
    expect(
      () => assertNoPreciseLocation({'longitude': '120'}),
      throwsStateError,
    );
  });

  test('guidesForCity 按城市过滤', () {
    expect(guidesForCity('北京').length, 2);
    expect(guidesForCity('火星'), isEmpty);
  });
}
