import 'package:flutter/material.dart';

/// The first-run permission explanation is shown AFTER account setup.
/// Android does not allow silent grants at installation, and pushing every
/// sensitive permission at first launch is not Play-compliant.
/// Only approved nearby discovery can request approximate location now.
class ReachPermissionIntro extends StatefulWidget {
  const ReachPermissionIntro({
    super.key,
    required this.onEnableNearby,
    required this.onContinueWithout,
  });
  final Future<bool> Function() onEnableNearby;
  final Future<void> Function() onContinueWithout;

  @override
  State<ReachPermissionIntro> createState() => _ReachPermissionIntroState();
}

class _ReachPermissionIntroState extends State<ReachPermissionIntro> {
  bool working = false;

  Future<void> enable() async {
    if (working) return;
    setState(() => working = true);
    try {
      final done = await widget.onEnableNearby();
      if (!done && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Location was not enabled. You can still use '
              'Reach without GPS, or try again later from Profile.'),
        ));
      }
    } finally {
      if (mounted) setState(() => working = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Set up permissions')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 510),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(Icons.phonelink_setup_outlined, size: 54,
                      color: colors.primary),
                  const SizedBox(height: 13),
                  Text('Reach works without extra permissions',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 10),
                  const Text('Choose how Reach uses your phone. '
                      'You can change your choice later in Profile or '
                      'Android Settings.', textAlign: TextAlign.center),
                  const SizedBox(height: 23),
                  const Card(
                    child: ListTile(
                      leading: Icon(Icons.location_on_outlined),
                      title: Text('Approximate location — optional'),
                      subtitle: Text('Helps discover nearby requests. '
                          'Only a rounded area is shared; your exact '
                          'GPS coordinates are never uploaded.'),
                    ),
                  ),
                  const Card(
                    child: ListTile(
                      leading: Icon(Icons.folder_open_outlined),
                      title: Text('Photos, videos and files'),
                      subtitle: Text('The Android picker opens when '
                          'you attach something. No broad storage '
                          'permission is needed.'),
                    ),
                  ),
                  const Card(
                    child: ListTile(
                      leading: Icon(Icons.mic_none_outlined),
                      title: Text('Microphone and camera'),
                      subtitle: Text('Not requested because voice/video '
                          'calling is not enabled in this release.'),
                    ),
                  ),
                  const Card(
                    child: ListTile(
                      leading: Icon(Icons.notifications_off_outlined),
                      title: Text('Notifications'),
                      subtitle: Text('Remote push notifications are '
                          'not enabled in the current release.'),
                    ),
                  ),
                  const SizedBox(height: 22),
                  FilledButton.icon(
                    onPressed: working ? null : enable,
                    icon: const Icon(Icons.my_location_outlined),
                    label: Padding(
                      padding: const EdgeInsets.all(13),
                      child: Text(working
                          ? 'Checking location…'
                          : 'Enable approximate nearby discovery'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton(
                    onPressed: working ? null : widget.onContinueWithout,
                    child: const Padding(
                      padding: EdgeInsets.all(13),
                      child: Text('Continue without location'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text('No microphone, camera or storage permission '
                      'will be requested on this screen.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
