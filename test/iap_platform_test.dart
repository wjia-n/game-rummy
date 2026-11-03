import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rummy/services/iap_service.dart';

void main() {
  test('iOS maps to the single Gold Star product', () {
    expect(StoreService.productIdsFor(TargetPlatform.iOS), {'rummystar'});
    expect(StoreService.starId, 'rummystar');
  });
  test('Android maps to coffee + chocolate only', () {
    expect(StoreService.productIdsFor(TargetPlatform.android),
        {'rummycoffee', 'rummychocolate'});
    expect(StoreService.productIdsFor(TargetPlatform.android),
        isNot(contains('rummystar')));
  });
}
