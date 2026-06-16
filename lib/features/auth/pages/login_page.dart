import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/providers/auth_provider.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/ios_tactile.dart';

/// 全屏强制登录页：未登录不允许进入应用，不提供任何「跳过/稍后」入口。
class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final auth = context.watch<AuthProvider>();
    final authorizing = auth.isAuthorizing;

    return Scaffold(
      backgroundColor: cs.surface,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(22),
                    child: Image.asset(
                      'assets/sakrylle_icon.png',
                      width: 96,
                      height: 96,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(height: 28),
                  Text(
                    l10n.loginPageTitle,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    l10n.loginPageSubtitle,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.4,
                      color: cs.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                  const SizedBox(height: 36),
                  _LoginButton(
                    label: authorizing
                        ? l10n.loginPageLoggingIn
                        : l10n.loginPageButton,
                    loading: authorizing,
                    onTap: authorizing
                        ? null
                        : () async {
                            final messenger = ScaffoldMessenger.of(context);
                            final failedText = l10n.loginPageFailed;
                            final ok = await context.read<AuthProvider>().login(
                              context,
                            );
                            if (!context.mounted) return;
                            if (!ok) {
                              messenger.showSnackBar(
                                SnackBar(content: Text(failedText)),
                              );
                            }
                          },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LoginButton extends StatelessWidget {
  const _LoginButton({
    required this.label,
    required this.loading,
    required this.onTap,
  });

  final String label;
  final bool loading;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final enabled = onTap != null;
    final bg = enabled ? cs.primary : cs.primary.withValues(alpha: 0.5);
    return SizedBox(
      width: double.infinity,
      child: IosCardPress(
        baseColor: bg,
        borderRadius: BorderRadius.circular(14),
        pressedBlendStrength: 0.12,
        padding: const EdgeInsets.symmetric(vertical: 14),
        onTap: onTap,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (loading) ...[
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(cs.onPrimary),
                ),
              ),
              const SizedBox(width: 10),
            ],
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: cs.onPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
