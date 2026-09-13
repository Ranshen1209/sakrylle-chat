import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sakrylle_chat/core/services/backup/backup_cancel_token.dart';
import 'package:sakrylle_chat/features/backup/backup_restore_error_message.dart';
import 'package:sakrylle_chat/l10n/app_localizations.dart';

void main() {
  testWidgets('returns a generic restore error message', (tester) async {
    late BuildContext context;
    await tester.pumpWidget(
      WidgetsApp(
        color: const Color(0xFFFFFFFF),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        builder: (buildContext, child) {
          context = buildContext;
          return const SizedBox.shrink();
        },
      ),
    );

    expect(
      backupRestoreErrorMessage(
        AppLocalizations.of(context)!,
        const FormatException('invalid backup'),
      ),
      'FormatException: invalid backup',
    );
    expect(
      backupRestoreErrorMessage(
        AppLocalizations.of(context)!,
        const BackupCancelledException(),
      ),
      'Cancelled',
    );
  });
}
