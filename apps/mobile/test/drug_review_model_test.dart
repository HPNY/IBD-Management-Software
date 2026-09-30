import 'package:flutter_test/flutter_test.dart';
import 'package:ibd_mobile/core/drug/drug_review_model.dart';

void main() {
  test('drugReviewUploadPayload 仅含白名单键', () {
    const r = DrugReview(
      drugName: '乌帕替尼',
      ibdType: 'CD',
      efficacy: 4,
      seSideEffect: 1,
      sideEffectTypes: ['感染'],
      stillUsing: true,
      comment: '有效但易感冒',
    );
    final p = drugReviewUploadPayload(r);
    expect(p.keys.toSet().every(kDrugReviewUploadKeys.contains), isTrue);
    expect(p['drugName'], '乌帕替尼');
    expect(p['efficacy'], 4);
    expect(p.containsKey('patientId'), isFalse);
  });

  test('comment 空不上传', () {
    const r = DrugReview(
      drugName: '美沙拉嗪',
      ibdType: 'UC',
      efficacy: 3,
      seSideEffect: 0,
      comment: '  ',
    );
    final p = drugReviewUploadPayload(r);
    expect(p.containsKey('comment'), isFalse);
  });

  test('aggregateLocal 均分与副作用分布', () {
    final list = [
      const DrugReview(
        drugName: 'A',
        ibdType: 'CD',
        efficacy: 5,
        seSideEffect: 0,
      ),
      const DrugReview(
        drugName: 'A',
        ibdType: 'UC',
        efficacy: 3,
        seSideEffect: 2,
      ),
      const DrugReview(
        drugName: 'B',
        ibdType: 'CD',
        efficacy: 1,
        seSideEffect: 3,
      ),
    ];
    final agg = aggregateLocal('A', list);
    expect(agg.count, 2);
    expect(agg.avgEfficacy, 4.0);
    expect(agg.seDist[0], 1);
    expect(agg.seDist[2], 1);
    expect(aggregateLocal('C', list).count, 0);
  });
}
