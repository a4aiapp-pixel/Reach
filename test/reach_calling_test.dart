import 'package:flutter_test/flutter_test.dart';
import 'package:reach_network/reach_calling.dart';

void main(){
  test('Only terminal call states suppress further media exchange',(){
    for(final value in ['declined','cancelled','ended','missed']){
      expect(ReachCalls.isTerminal(value),isTrue,reason:value);
    }
    for(final value in ['ringing','accepted']){
      expect(ReachCalls.isTerminal(value),isFalse,reason:value);
    }
  });
}
