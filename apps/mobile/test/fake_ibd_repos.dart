import 'package:ibd_mobile/core/db/repositories.dart';

/// UI 测试共享内存：打卡与排便细表读同一份数据。
class InMemoryIbdStore {
  final Map<String, Map<String, dynamic>> symptoms = {};
  final List<Map<String, dynamic>> bathrooms = [];

  static String bloodFlag(String? bloodyStool) {
    switch (bloodyStool) {
      case 'none':
        return '0';
      case 'trace':
        return '1';
      case 'obvious':
        return '2';
      default:
        return '';
    }
  }
}

/// 与生产 SymptomRepository.upsert 同契约：保存打卡时同步排便细表。
class FakeSymptomRepository extends SymptomRepository {
  FakeSymptomRepository(this.store) : super();

  final InMemoryIbdStore store;

  @override
  Future<void> upsert({
    required String date,
    int? painLevel,
    int? diarrheaCount,
    int? stoolType,
    String? bloodyStool,
    int? bloating,
    int? fatigue,
    bool? nausea,
    String? overallFeeling,
    bool? urgency,
    bool? mucus,
    int? bowelCount,
  }) async {
    store.symptoms[date] = {
      'id': 'sym-$date',
      'date': date,
      'pain_level': painLevel,
      'diarrhea_count': diarrheaCount,
      'stool_type': stoolType,
      'bloody_stool': bloodyStool,
      'bloating': bloating,
      'fatigue': fatigue,
      'nausea': nausea == null ? null : (nausea ? 1 : 0),
      'overall_feeling': overallFeeling,
      'urgency': urgency == null ? null : (urgency ? 1 : 0),
      'mucus': mucus == null ? null : (mucus ? 1 : 0),
      'bowel_count': bowelCount,
    };

    final hasBathroomPayload = stoolType != null ||
        urgency != null ||
        mucus != null ||
        bloodyStool != null ||
        bowelCount != null ||
        diarrheaCount != null;
    if (!hasBathroomPayload) return;

    final n = DateTime.now();
    final time =
        '${n.hour.toString().padLeft(2, '0')}:${n.minute.toString().padLeft(2, '0')}';
    store.bathrooms.removeWhere(
      (r) => r['date'] == date && r['source'] == 'checkin',
    );
    final bloodText = bloodyStool;
    int? bloodFlag;
    if (bloodText == 'none') {
      bloodFlag = 0;
    } else if (bloodText == 'trace') {
      bloodFlag = 1;
    } else if (bloodText == 'obvious') {
      bloodFlag = 2;
    }
    store.bathrooms.add({
      'id': 'bath-checkin-$date-${n.microsecondsSinceEpoch}',
      'date': date,
      'time': time,
      'stool_type': stoolType,
      'urgency': urgency == null ? null : (urgency ? 1 : 0),
      'blood': bloodFlag,
      'mucus': mucus == null ? null : (mucus ? 1 : 0),
      'source': 'checkin',
      'daily_count': bowelCount,
      'diarrhea_count': diarrheaCount,
      'notes': '打卡同步',
    });
  }

  @override
  Future<Map<String, dynamic>?> getByDate(String date) async {
    return store.symptoms[date];
  }

  @override
  Future<List<Map<String, dynamic>>> listAll() async {
    final rows = store.symptoms.values.toList()
      ..sort((a, b) => ('${b['date']}').compareTo('${a['date']}'));
    return rows;
  }
}

class FakeBathroomRepository extends BathroomRepository {
  FakeBathroomRepository(this.store) : super();

  final InMemoryIbdStore store;

  @override
  Future<void> insert({
    required String date,
    String? time,
    int? stoolType,
    bool? urgency,
    bool? blood,
    bool? mucus,
    String? notes,
    int? dailyCount,
  }) async {
    final n = DateTime.now();
    store.bathrooms.add({
      'id': 'bath-manual-${n.microsecondsSinceEpoch}',
      'date': date,
      'time': time,
      'stool_type': stoolType,
      'urgency': urgency == null ? null : (urgency ? 1 : 0),
      'blood': blood == null ? null : (blood ? 1 : 0),
      'mucus': mucus == null ? null : (mucus ? 1 : 0),
      'notes': notes,
      'source': 'manual',
      'daily_count': dailyCount,
    });
  }

  @override
  Future<List<Map<String, dynamic>>> listAll() async {
    final rows = store.bathrooms
        .map((r) => Map<String, dynamic>.from(r))
        .toList();
    rows.sort((a, b) {
      final byDate = ('${b['date']}').compareTo('${a['date']}');
      if (byDate != 0) return byDate;
      return ('${b['time'] ?? ''}').compareTo('${a['time'] ?? ''}');
    });
    return rows;
  }

  @override
  Future<List<Map<String, dynamic>>> listByDate(String date) async {
    final rows = store.bathrooms
        .where((r) => r['date'] == date)
        .map((r) => Map<String, dynamic>.from(r))
        .toList();
    rows.sort(
      (a, b) => ('${b['time'] ?? ''}').compareTo('${a['time'] ?? ''}'),
    );
    return rows;
  }
}

String uiTodayIso() {
  final n = DateTime.now();
  return '${n.year.toString().padLeft(4, '0')}-'
      '${n.month.toString().padLeft(2, '0')}-'
      '${n.day.toString().padLeft(2, '0')}';
}
