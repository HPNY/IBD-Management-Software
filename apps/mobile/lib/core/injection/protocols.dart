/// 注射协议（与服务端 injection.protocols 对齐，本地生成不依赖云）。
class ProtocolSlot {
  ProtocolSlot({
    required this.week,
    required this.route,
    required this.phase,
    required this.dose,
    this.label,
  });

  final int week;
  final String route;
  final String phase;
  final String dose;
  final String? label;
}

class InjectionProtocol {
  InjectionProtocol({
    required this.drugKey,
    required this.drugName,
    required this.induction,
    required this.startWeek,
    required this.intervalWeeks,
    required this.maintenanceRoute,
    required this.maintenanceDose,
    this.maintenanceCount = 12,
  });

  final String drugKey;
  final String drugName;
  final List<ProtocolSlot> induction;
  final int startWeek;
  final int intervalWeeks;
  final String maintenanceRoute;
  final String maintenanceDose;
  final int maintenanceCount;
}

final kProtocols = <InjectionProtocol>[
  InjectionProtocol(
    drugKey: 'skyrizi',
    drugName: '利生奇珠单抗（喜开悦）',
    induction: [
      ProtocolSlot(week: 0, route: 'iv', phase: 'induction', dose: '600mg', label: 'W0'),
      ProtocolSlot(week: 4, route: 'iv', phase: 'induction', dose: '600mg', label: 'W4'),
      ProtocolSlot(week: 8, route: 'iv', phase: 'induction', dose: '600mg', label: 'W8'),
    ],
    startWeek: 12,
    intervalWeeks: 8,
    maintenanceRoute: 'sc',
    maintenanceDose: '180mg',
  ),
  InjectionProtocol(
    drugKey: 'humira',
    drugName: '阿达木单抗（修美乐）',
    induction: [
      ProtocolSlot(week: 0, route: 'sc', phase: 'induction', dose: '160mg'),
      ProtocolSlot(week: 2, route: 'sc', phase: 'induction', dose: '80mg'),
    ],
    startWeek: 4,
    intervalWeeks: 2,
    maintenanceRoute: 'sc',
    maintenanceDose: '40mg',
    maintenanceCount: 24,
  ),
];

List<Map<String, dynamic>> buildSchedule({
  required InjectionProtocol protocol,
  required DateTime start,
}) {
  String iso(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  final rows = <Map<String, dynamic>>[];
  for (final s in protocol.induction) {
    final planned = start.add(Duration(days: s.week * 7));
    rows.add({
      'drug': protocol.drugName,
      'plannedDate': iso(planned),
      'phase': s.phase,
      'dose': s.dose,
      'route': s.route,
      'weekNumber': s.week,
      'notes': s.label,
    });
  }
  for (var i = 0; i < protocol.maintenanceCount; i++) {
    final week = protocol.startWeek + i * protocol.intervalWeeks;
    final planned = start.add(Duration(days: week * 7));
    rows.add({
      'drug': protocol.drugName,
      'plannedDate': iso(planned),
      'phase': 'maintenance',
      'dose': protocol.maintenanceDose,
      'route': protocol.maintenanceRoute,
      'weekNumber': week,
      'notes': null,
    });
  }
  return rows;
}
