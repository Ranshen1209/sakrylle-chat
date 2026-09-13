import 'package:flutter/material.dart';

import 'package:sakrylle_chat/core/services/haptics.dart';
import 'package:sakrylle_chat/features/workspace/widgets/environment/environment_pane.dart';
import 'package:sakrylle_chat/icons/lucide_adapter.dart';
import 'package:sakrylle_chat/l10n/app_localizations.dart';
import 'package:sakrylle_chat/shared/widgets/ios_tactile.dart';

class EnvironmentPageMobileLayout extends StatelessWidget {
  const EnvironmentPageMobileLayout({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        leading: Tooltip(
          message: l10n.settingsPageBackButton,
          child: IosIconButton(
            icon: Lucide.ArrowLeft,
            color: cs.onSurface,
            size: 22,
            minSize: 44,
            semanticLabel: l10n.settingsPageBackButton,
            onTap: () {
              Haptics.light();
              Navigator.of(context).maybePop();
            },
          ),
        ),
        title: Text(l10n.workspaceEnvTitle),
      ),
      body: const EnvironmentPane(),
    );
  }
}
