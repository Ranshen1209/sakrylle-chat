# 开发与验证

Sakrylle Chat 基于 [Chevey339/kelivo](https://github.com/Chevey339/kelivo)，保留仓库 LICENSE 与上游归属。

本次上游集成要求 Flutter 3.44.9，配套 Dart 3.12.2。`.fvmrc` 是本地版本声明，启用的 CI 使用相同版本。应用的 `pubspec.lock` 应提交，避免每次检出重新浮动解析依赖。

安装 Dart 与 FVM 后，在仓库根目录运行：

```sh
dart pub global activate fvm
fvm install
fvm use --force
fvm flutter pub get
fvm flutter gen-l10n
mkdir -p lib/secrets
printf "const String siliconflowFallbackKey = '';\n" > lib/secrets/fallback.dart
fvm dart run build_runner build --delete-conflicting-outputs
fvm dart analyze --fatal-infos lib test
fvm flutter test
```

`.fvm/` 为本地缓存，不提交 SDK 符号链接或个人绝对路径。公开客户端不得注入共享生产 API 密钥；`lib/secrets/fallback.dart` 仅为空兼容常量。

本轮上游参考为 `Chevey339/kelivo master baa0de9eef851268d46ec95a7379ca3b5b1759c5`，上游版本 `1.2.7+76`。Sakrylle 候选版本为 `1.2.7+77`；正式标签及签名验证以正式发布记录为准，版本号存在不代表已经发布。

平台登录说明见 [Sakrylle Chat 官方文档](https://doc.sakrylle.com/apps/chat)。本地协议事实应只读核对相邻 `Sakrylle API` 项目代码及 `Sakrylle Docs/apps/chat.md`，不再引用已不存在的 `sub2api/sakrylle-docs`。

本次合并引入上游 SQLite 存储与恢复入口。必须验证 1.1.15 的 Hive 和设置迁移，并保留原始备份；未证明旧客户端能读取新数据前，不允许把下载入口回退解释为安全的数据降级。

## 原生构建依赖

macOS 需要 Xcode、命令行工具与 CocoaPods。iOS 新增工作区内核还需要 `brew install meson ninja llvm lld pkgconf libarchive`；构建脚本 `ios/sandbox/ensure_artifacts.sh` 会检查工具并生成内核，不提交生成二进制。

终端依赖沿用上游固定 strut、零 leading 的行高实现。其旧 golden 使用旧字体行距，本轮对照渲染和 `terminal_text_style_test.dart` 后重新生成；没有调整像素容差或跳过测试。数学依赖修复了缺失的选择委托及程序设置选区时的手柄遮挡。

## 官方归档索引不可用时

本机访问 Flutter 官方发行索引返回 HTTP 404，因此本轮实际采用官方 Git 仓库 tag 建立 SDK，CI 使用相同方法并校验 commit。FVM 正常安装失败时，可在 FVM 缓存目录中克隆 `https://github.com/flutter/flutter.git` 的 `3.44.9` tag，确认 `git rev-parse HEAD` 为 `6b182d2c7585eba26d4edce0f97630effd256c33`，运行该 SDK 的 `bin/flutter --version` 完成初始化，然后重新执行 `fvm use 3.44.9 --force --skip-pub-get`。用 `fvm config` 查询缓存位置，勿把个人路径写入仓库。
