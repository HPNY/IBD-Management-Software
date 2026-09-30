/// D3：同城档案与就诊指南（本地；无精确位置）。
library;

class GeoProfile {
  const GeoProfile({
    required this.nickname,
    required this.city,
  });

  final String nickname;
  final String city;

  /// 上传/展示白名单：仅昵称与城市，禁止经纬度。
  Map<String, dynamic> toPublicJson() => {
        'nickname': nickname,
        'city': city,
      };
}

/// 就诊指南数据版本（结构变更时 +1）。
const kCityGuideVersion = 1;

class CityGuide {
  const CityGuide({
    required this.city,
    required this.hospital,
    required this.department,
    this.specialty,
    this.tips,
  });

  final String city;
  final String hospital;
  final String department;
  final String? specialty;
  final String? tips;
}

const kCityGuide = <CityGuide>[
  CityGuide(
    city: '北京',
    hospital: '北京协和医院',
    department: '消化内科',
    specialty: '疑难型',
    tips: '部分检查需提前预约',
  ),
  CityGuide(
    city: '北京',
    hospital: '中国人民解放军总医院',
    department: '消化内科',
    specialty: '药物型',
  ),
  CityGuide(
    city: '上海',
    hospital: '上海交通大学医学院附属瑞金医院',
    department: '消化内科',
    specialty: '疑难型',
  ),
  CityGuide(
    city: '上海',
    hospital: '复旦大学附属中山医院',
    department: '消化内科',
  ),
  CityGuide(
    city: '广州',
    hospital: '中山大学附属第一医院',
    department: '消化内科',
  ),
  CityGuide(
    city: '杭州',
    hospital: '浙江大学医学院附属邵逸夫医院',
    department: '消化内科',
  ),
  CityGuide(
    city: '成都',
    hospital: '四川大学华西医院',
    department: '消化内科',
    specialty: '手术型',
  ),
  CityGuide(
    city: '武汉',
    hospital: '华中科技大学同济医学院附属协和医院',
    department: '消化内科',
  ),
];

const kCities = [
  '北京',
  '上海',
  '广州',
  '深圳',
  '杭州',
  '成都',
  '武汉',
  '南京',
  '西安',
  '其他',
];

List<CityGuide> guidesForCity(String city) {
  return kCityGuide.where((g) => g.city == city).toList();
}

/// D3.5：断言公开 payload 不含精确位置字段。
void assertNoPreciseLocation(Map<String, dynamic> json) {
  const banned = {
    'lat',
    'lng',
    'latitude',
    'longitude',
    'gps',
    'address',
    'location',
    'coords',
  };
  for (final k in json.keys) {
    if (banned.contains(k.toLowerCase())) {
      throw StateError('forbidden location field: $k');
    }
  }
}
