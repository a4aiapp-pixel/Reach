import 'package:flutter_test/flutter_test.dart';
import 'package:reach_network/reach_local_assist.dart';

void main() {
  test('Local assistant covers all zero-cost tools without cloud access', () {
    expect(ReachLocalAssist.modes.keys, containsAll(
      ['chat','draft','polish','translate','safety','ideas']));
    for(final mode in ReachLocalAssist.modes.keys){
      expect(ReachLocalAssist.respond(mode,'Please help with Excel'),
        isNotEmpty);
    }
  });
  test('Local editor preserves the users actual message and punctuation', () {
    expect(ReachLocalAssist.cleanText('pls   help me'), 'Please help me.');
    expect(ReachLocalAssist.cleanText('im ready'),
      "I'm ready.");
    expect(ReachLocalAssist.cleanText('hi ,friend'),'Hi, friend.');
  });
  test('Drafts show editable placeholders, do not invent private details', () {
    final draft=ReachLocalAssist.draft('I can teach math');
    expect(draft,contains('Offer to help'));
    expect(draft,contains('Learning'));
    expect(draft,contains('[day or time window]'));
    expect(draft,contains('Nothing has been posted automatically'));
  });
  test('Safety checker warns about payment pressure and OTP disclosure', () {
    final result=ReachLocalAssist.safety(
      'Urgent transfer money and tell me your OTP code');
    expect(result,contains('verification codes'));
    expect(result,contains('advance payments'));
    expect(result,contains('not a verified fraud finding'));
  });
  test('Phrasebook never fabricates arbitrary machine translation', () {
    final result=ReachLocalAssist.phrases(
      'Translate this message to Urdu: tomorrow at 6:00');
    expect(result,contains('not arbitrary machine translation'));
    expect(result,contains('شکریہ'));
  });
  test('General guidance does not claim access to live matches', () {
    final result=ReachLocalAssist.guidance('Find people nearby now');
    expect(result,contains('no network AI'));
  });
}
