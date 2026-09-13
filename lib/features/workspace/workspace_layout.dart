import 'package:flutter/widgets.dart';

import 'package:sakrylle_chat/shared/responsive/screen_type_helper.dart';
import 'package:sakrylle_chat/utils/platform_utils.dart';

/// Desktop windows keep mouse/keyboard dialogs even when resized below the
/// large-screen breakpoint. Layouts still measure their own available space.
bool useDesktopWorkspaceLayout(BuildContext context) =>
    PlatformUtils.isDesktopTarget || ResponsiveHelper.isDesktop(context);
