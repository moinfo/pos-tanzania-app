import 'package:flutter/material.dart';

import '../models/app_version_info.dart';
import '../services/force_update.dart';
import '../services/update_service.dart';

/// Covers the whole app once the server has refused this build.
///
/// Mounted in MaterialApp.builder, above the Navigator, so it sits over every
/// route and dialog and no back press or pushed screen gets past it.
class ForceUpdateGate extends StatelessWidget {
  const ForceUpdateGate({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ForceUpdateInfo?>(
      valueListenable: ForceUpdate.required,
      child: child,
      builder: (context, info, child) {
        if (info == null) return child!;
        return Stack(
          children: [
            // Kept mounted so no in-progress state is torn down, but unreachable.
            ExcludeFocus(child: IgnorePointer(child: child!)),
            PopScope(canPop: false, child: _ForceUpdateScreen(info: info)),
          ],
        );
      },
    );
  }
}

class _ForceUpdateScreen extends StatefulWidget {
  const _ForceUpdateScreen({required this.info});

  final ForceUpdateInfo info;

  @override
  State<_ForceUpdateScreen> createState() => _ForceUpdateScreenState();
}

class _ForceUpdateScreenState extends State<_ForceUpdateScreen> {
  bool _opening = false;
  bool _noStore = false;

  Future<void> _openStore() async {
    setState(() {
      _opening = true;
      _noStore = false;
    });
    final opened = await UpdateService().openStore(
      AppVersionInfo(
        platform: '',
        versionName: '',
        versionCode: widget.info.minVersionCode,
        storeUrl: widget.info.storeUrl,
      ),
    );
    if (!mounted) return;
    setState(() {
      _opening = false;
      _noStore = !opened;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: theme.colorScheme.surface,
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.system_update,
                    size: 72, color: theme.colorScheme.primary),
                const SizedBox(height: 24),
                Text(
                  'Update required',
                  style: theme.textTheme.headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w600),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  widget.info.message,
                  style: theme.textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _opening ? null : _openStore,
                    icon: const Icon(Icons.shop),
                    label: const Text('Update now'),
                  ),
                ),
                if (_noStore) ...[
                  const SizedBox(height: 12),
                  Text(
                    'Could not open the store. Open Play Store and update the app from there.',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.error),
                    textAlign: TextAlign.center,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
