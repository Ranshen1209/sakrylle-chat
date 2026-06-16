/// Sakrylle 分组路由前缀工具。
///
/// Sakrylle 网关用 `"<groupId>:<model>"` 形态的 model id 作为「分组选择器」
/// （见 RP 接入指南 §18.3，保留 `^<digits>:` 语法）。该前缀只在发送给网关的
/// 请求体 `model` 字段中保留以触发按组路由计费；在品牌图标、能力推断、UI 显示
/// 等「展示层」需要剥离前缀，按干净模型名处理。
library;

final RegExp _sakrylleGroupPrefix = RegExp(r'^\d+:');

/// 解析出分组前缀的数字 groupId；无前缀返回 null。
int? sakrylleGroupIdOf(String modelId) {
  final m = RegExp(r'^(\d+):').firstMatch(modelId);
  if (m == null) return null;
  return int.tryParse(m.group(1)!);
}

/// 去掉前导 `"<digits>:"` 分组前缀，得到干净模型名；无前缀时原样返回。
String stripSakrylleGroupPrefix(String modelId) =>
    modelId.replaceFirst(_sakrylleGroupPrefix, '');
