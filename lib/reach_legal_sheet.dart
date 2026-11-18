import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'config.dart';

/// Consistent in-app disclosures for signup, settings and account setup.
/// Production builds must additionally link to real published operator policies.
Future<void> showReachLegalSummary(BuildContext context) async {
  final base=AppConfig.legalBase.endsWith('/')
      ?AppConfig.legalBase.substring(0,AppConfig.legalBase.length-1)
      :AppConfig.legalBase;
  await showModalBottomSheet<void>(
    context:context,isScrollControlled:true,showDragHandle:true,
    builder:(sheetContext)=>SafeArea(
      child:FractionallySizedBox(
        heightFactor:.84,
        child:ListView(padding:const EdgeInsets.all(22),children:[
          Text('Privacy & community rules',
            style:Theme.of(sheetContext).textTheme.headlineSmall),
          const SizedBox(height:12),
          const Text('Reach is an 18+ community for voluntary, lawful '
            'requests, offers of help and permission-based connections. '
            'Be respectful. Do not post scams, impersonate people, harass '
            'others, share sensitive personal information or arrange unsafe '
            'or coercive transactions. Report and block suspicious contacts.'),
          const SizedBox(height:16),
          Text('What data Reach uses',
            style:Theme.of(sheetContext).textTheme.titleMedium),
          const SizedBox(height:8),
          const Text('Your email is used for account verification. Reach also '
            'stores your public display name, chosen username, city, country, '
            'optional profile details, posts, connection requests, private '
            'chat messages and attachments, circles, blocked contacts and '
            'abuse reports. Nearby discovery is optional; if enabled, '
            'coordinates are rounded to an approximate grid before uploading.'),
          const SizedBox(height:12),
          const Text('Accepted connections can access their conversations. '
            'Uploaded files are private by default and currently limited '
            'to supported formats and 6 MB each. Not all files are scanned '
            'for malicious content, so never open files from strangers '
            'without checking them. Chat messages are not represented as '
            'end-to-end encrypted.'),
          const SizedBox(height:12),
          const Text('Free local Reach Assist tools process text on this '
            'device without contacting an AI provider. Optional cloud AI '
            'is disabled by default. Voice/video calling and commercial '
            'payments require separate release approval and activation.'),
          const SizedBox(height:12),
          const Text('You can change location permissions, block members, '
            'report abuse or delete your Reach account in Profile. '
            'Account deletion also removes stored private chat attachments. '
            'Use a public place for an initial meetup and never share OTP '
            'codes or banking credentials.'),
          if(base.startsWith('https://')) ...[
            const SizedBox(height:18),
            OutlinedButton.icon(
              icon:const Icon(Icons.privacy_tip_outlined),
              label:const Text('Full privacy policy'),
              onPressed:()=>launchUrl(Uri.parse('$base/privacy.html'),
                mode:LaunchMode.externalApplication)),
            OutlinedButton.icon(
              icon:const Icon(Icons.gavel_outlined),
              label:const Text('Full community rules'),
              onPressed:()=>launchUrl(Uri.parse('$base/terms.html'),
                mode:LaunchMode.externalApplication)),
            TextButton(
              onPressed:()=>launchUrl(Uri.parse('$base/delete-account.html'),
                mode:LaunchMode.externalApplication),
              child:const Text('External account deletion instructions')),
          ] else ...[
            const SizedBox(height:18),
            const Text('Public legal pages have not yet been configured '
              'for this test version.',
              style:TextStyle(fontStyle:FontStyle.italic)),
          ],
          const SizedBox(height:10),
          FilledButton(
            onPressed:()=>Navigator.pop(sheetContext),
            child:const Text('Close')),
        ]),
      ),
    ),
  );
}
