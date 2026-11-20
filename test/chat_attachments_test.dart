import 'package:flutter_test/flutter_test.dart';
import 'package:reach_network/chat_attachments.dart';

void main(){
  group('Private chat attachment rules',(){
    test('Common safe document, photo, audio and video formats are supported',(){
      expect(ReachAttachments.mimeFor('FORM.PDF'),'application/pdf');
      expect(ReachAttachments.mimeFor('data.xlsx'),
        'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
      expect(ReachAttachments.mimeFor('picture.jpeg'),'image/jpeg');
      expect(ReachAttachments.mimeFor('recording.m4a'),'audio/mp4');
      expect(ReachAttachments.mimeFor('clip.mp4'),'video/mp4');
    });
    test('Executable and unsupported extensions are not shareable',(){
      for(final bad in ['setup.exe','app.apk','macro.bat','download.js',
        'hidden.sh','unknown.xyz','package.zip']){
        expect(ReachAttachments.mimeFor(bad),isEmpty,reason:bad);
      }
    });
    test('Native filenames are sanitized without changing permitted suffix',(){
      expect(ReachAttachments.cleanFilename('some/file.pdf'),'some_file.pdf');
      expect(ReachAttachments.cleanFilename('hello.JPG'),'hello.jpg');
      expect(ReachAttachments.cleanFilename('note.txt').length,lessThanOrEqualTo(180));
      expect(()=>ReachAttachments.cleanFilename('launch.apk'),throwsArgumentError);
      expect(()=>ReachAttachments.cleanFilename('.exe'),throwsArgumentError);
    });
    test('Server and client agree on the per-file upload size ceiling',(){
      expect(ReachAttachments.maxBytes,25165824);
      expect(ReachAttachments.categoryLimit('image/jpeg'),8388608);
      expect(ReachAttachments.categoryLimit('audio/mpeg'),12582912);
      expect(ReachAttachments.categoryLimit('video/mp4'),25165824);
      expect(ReachAttachments.categoryLimit('application/pdf'),16777216);
    });
  });
}
