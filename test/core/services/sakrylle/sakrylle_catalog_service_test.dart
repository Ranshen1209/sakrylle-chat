import 'package:flutter_test/flutter_test.dart';
import 'package:sakrylle_chat/core/services/sakrylle/sakrylle_catalog_service.dart';
import 'package:sakrylle_chat/core/utils/openai_model_compat.dart';
import 'package:sakrylle_chat/utils/sakrylle_model_id.dart';

void main() {
  group('Sakrylle group-routing model id', () {
    test('strips and reads group prefix for display/branding', () {
      expect(stripSakrylleGroupPrefix('12:claude-opus-4-6'), 'claude-opus-4-6');
      expect(sakrylleGroupIdOf('12:claude-opus-4-6'), 12);
      // No prefix is left untouched.
      expect(stripSakrylleGroupPrefix('gpt-5.5'), 'gpt-5.5');
      expect(sakrylleGroupIdOf('gpt-5.5'), isNull);
      // A model name that merely contains a colon (no leading digits) is not a
      // group selector and must be preserved verbatim.
      expect(stripSakrylleGroupPrefix('vendor:model'), 'vendor:model');
      expect(sakrylleGroupIdOf('vendor:model'), isNull);
    });

    test('send path keeps the group prefix on the request model id', () {
      // The stored model KEY is "<gid>:<model>"; overrides carry only display
      // metadata (no apiModelId), so the resolver must return the key verbatim
      // — that prefix is what triggers per-group routing/billing at the gateway.
      const override = <String, dynamic>{
        'name': 'claude-opus-4-6',
        'groupId': 12,
        'groupName': 'Claude-Max',
        'rateMultiplier': 2.0,
      };
      expect(
        resolveApiModelIdOverride(override, '12:claude-opus-4-6'),
        '12:claude-opus-4-6',
      );
    });
  });

  group('SakrylleCatalogService.parseGroupedModels', () {
    test('expands models with available_groups metadata', () {
      final decoded = {
        'object': 'list',
        'data': [
          {
            'id': 'claude-opus-4-6',
            'object': 'model',
            'available_groups': [
              {'id': 7, 'name': 'Claude-Code', 'rate_multiplier': 0.6},
              {'id': 12, 'name': 'Claude-Max', 'rate_multiplier': 2.0},
            ],
          },
          {
            'id': 'gpt-5.5',
            'groups': [
              {'id': 5, 'name': 'GPT-Pro', 'rate_multiplier': '0.5'},
            ],
          },
        ],
      };

      final models = SakrylleCatalogService.parseGroupedModels(decoded);

      expect(models.map((m) => m.routeId), [
        '7:claude-opus-4-6',
        '12:claude-opus-4-6',
        '5:gpt-5.5',
      ]);
      expect(models.map((m) => m.groupName), [
        'Claude-Code',
        'Claude-Max',
        'GPT-Pro',
      ]);
      expect(models.map((m) => m.rateMultiplier), [0.6, 2.0, 0.5]);
    });

    test('parses grouped models with id, display_name and group fields', () {
      final decoded = {
        'object': 'list',
        'data': [
          {
            'id': '12:claude-opus-4-6',
            'object': 'model',
            'display_name': 'claude-opus-4-6',
            'group': {'id': 12, 'name': 'Claude-Max', 'rate_multiplier': 2.0},
          },
          {
            'id': '7:claude-opus-4-6',
            'object': 'model',
            'display_name': 'claude-opus-4-6',
            'group': {'id': 7, 'name': 'Claude-Code', 'rate_multiplier': 0.6},
          },
        ],
      };

      final models = SakrylleCatalogService.parseGroupedModels(decoded);
      expect(models.length, 2);

      final a = models[0];
      expect(a.routeId, '12:claude-opus-4-6');
      expect(a.modelName, 'claude-opus-4-6');
      expect(a.groupId, 12);
      expect(a.groupName, 'Claude-Max');
      expect(a.rateMultiplier, 2.0);

      final b = models[1];
      expect(b.routeId, '7:claude-opus-4-6');
      expect(b.groupId, 7);
      expect(b.rateMultiplier, 0.6);
    });

    test('falls back to prefix-derived gid and stripped name', () {
      final decoded = {
        'data': [
          {
            'id': '5:gpt-5.5',
            // no display_name, no group object
          },
        ],
      };
      final models = SakrylleCatalogService.parseGroupedModels(decoded);
      expect(models.single.groupId, 5);
      expect(models.single.modelName, 'gpt-5.5');
      expect(models.single.rateMultiplier, 1.0);
      expect(models.single.groupName, '');
    });

    test('skips malformed entries and empty data', () {
      expect(SakrylleCatalogService.parseGroupedModels({}), isEmpty);
      final decoded = {
        'data': [
          'not-a-map',
          {'id': ''},
          {
            'id': '9:qwen',
            'group': {'name': 'Free'},
          },
        ],
      };
      final models = SakrylleCatalogService.parseGroupedModels(decoded);
      expect(models.length, 1);
      expect(models.single.routeId, '9:qwen');
      expect(models.single.groupId, 9);
      expect(models.single.groupName, 'Free');
    });
  });
}
