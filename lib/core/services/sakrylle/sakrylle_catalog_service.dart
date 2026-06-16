import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../utils/sakrylle_model_id.dart';
import '../../providers/settings_provider.dart';
import '../auth/sakrylle_oauth_service.dart';

/// 一个分组下的可路由模型（来自 `/v1/models?groups=all`，见 RP 接入指南 §18.2）。
class SakrylleGroupedModel {
  /// 路由 id：`"<groupId>:<model>"`，原样作为请求体 `model` 触发按组路由计费。
  final String routeId;

  /// 干净模型名（不含分组前缀），用于展示与品牌/能力推断。
  final String modelName;

  final int? groupId;
  final String groupName;
  final double rateMultiplier;

  const SakrylleGroupedModel({
    required this.routeId,
    required this.modelName,
    required this.groupId,
    required this.groupName,
    required this.rateMultiplier,
  });
}

class SakrylleCatalogException implements Exception {
  final String message;
  const SakrylleCatalogException(this.message);
  @override
  String toString() => 'SakrylleCatalogException: $message';
}

/// 拉取 Sakrylle 网关的「分组模型目录」并写入对应 provider 配置。
class SakrylleCatalogService {
  const SakrylleCatalogService._();

  /// 调用 `GET {baseUrl}/models?groups=all` 返回分组模型列表。
  static Future<List<SakrylleGroupedModel>> fetchGroupedModels(
    String baseUrl,
  ) async {
    final token = await SakrylleOAuthService.instance.getValidAccessToken();
    if (token.isEmpty) {
      throw const SakrylleCatalogException('Not logged in');
    }
    final base = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;
    final uri = Uri.parse('$base/models?groups=all');
    http.Response res;
    try {
      res = await http.get(uri, headers: {'Authorization': 'Bearer $token'});
    } catch (e) {
      throw SakrylleCatalogException(e.toString());
    }
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw SakrylleCatalogException('HTTP ${res.statusCode}: ${res.body}');
    }
    final Map<String, dynamic> decoded;
    try {
      decoded = jsonDecode(res.body) as Map<String, dynamic>;
    } catch (e) {
      throw SakrylleCatalogException('Invalid JSON: $e');
    }
    return parseGroupedModels(decoded);
  }

  /// 解析 `/v1/models?groups=all` 的响应体为分组模型列表（纯函数，便于测试）。
  static List<SakrylleGroupedModel> parseGroupedModels(
    Map<String, dynamic> decoded,
  ) {
    final data = (decoded['data'] as List?) ?? const [];
    final out = <SakrylleGroupedModel>[];
    for (final e in data) {
      if (e is! Map) continue;
      final id = (e['id'] ?? '').toString().trim();
      if (id.isEmpty) continue;
      final display = (e['display_name'] ?? '').toString().trim();
      final modelName = display.isNotEmpty
          ? display
          : stripSakrylleGroupPrefix(id);
      final groups = _groupsFor(e);
      if (groups.isEmpty) {
        out.add(_modelFromGroup(id, modelName, const <dynamic, dynamic>{}));
        continue;
      }
      for (final group in groups) {
        out.add(_modelFromGroup(id, modelName, group));
      }
    }
    return out;
  }

  static List<Map<dynamic, dynamic>> _groupsFor(Map<dynamic, dynamic> model) {
    final group = model['group'];
    if (group is Map) return [group];

    for (final key in const ['groups', 'available_groups', 'allowed_groups']) {
      final raw = model[key];
      if (raw is List) return raw.whereType<Map>().toList();
    }
    return const <Map<dynamic, dynamic>>[];
  }

  static SakrylleGroupedModel _modelFromGroup(
    String rawId,
    String modelName,
    Map<dynamic, dynamic> group,
  ) {
    final gid = group['id'] is num
        ? (group['id'] as num).toInt()
        : int.tryParse(group['id']?.toString() ?? '') ??
              sakrylleGroupIdOf(rawId);
    final routeId = gid == null || sakrylleGroupIdOf(rawId) != null
        ? rawId
        : '$gid:${stripSakrylleGroupPrefix(rawId)}';
    final mult = group['rate_multiplier'];
    final rate = mult is num
        ? mult.toDouble()
        : double.tryParse(mult?.toString() ?? '') ?? 1.0;
    return SakrylleGroupedModel(
      routeId: routeId,
      modelName: modelName,
      groupId: gid,
      groupName: (group['name'] ?? '').toString(),
      rateMultiplier: rate,
    );
  }

  /// 拉取并写入：把分组模型存为 `<gid>:<model>` 路由 id，
  /// 并在 modelOverrides 携带 `name`（干净名）+ 分组/倍率元数据。
  /// 返回写入的模型数量。
  static Future<int> refreshInto(
    SettingsProvider settings,
    String providerKey, {
    String? displayName,
  }) async {
    final cfg = settings.getProviderConfig(
      providerKey,
      defaultName: displayName,
    );
    final models = await fetchGroupedModels(cfg.baseUrl);

    final ids = <String>[];
    final overrides = <String, dynamic>{};
    for (final m in models) {
      ids.add(m.routeId);
      overrides[m.routeId] = <String, dynamic>{
        'name': m.modelName,
        if (m.groupId != null) 'groupId': m.groupId,
        'groupName': m.groupName,
        'rateMultiplier': m.rateMultiplier,
      };
    }

    await settings.setProviderConfig(
      providerKey,
      cfg.copyWith(models: ids, modelOverrides: overrides),
    );
    return ids.length;
  }
}
