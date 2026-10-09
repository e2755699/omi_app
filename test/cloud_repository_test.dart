import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:omi_app/data/sync/cloud_repository.dart';
import 'package:omi_app/data/sync/local_sync_database.dart';

class TestRepository extends CloudRepository {
  TestRepository(super.client) : super(userId: 'alice', groupId: 'group');
  @override
  bool get authorized => true;
}

void main() {
  http.Response response(http.Request request, Object? body) =>
      http.Response(jsonEncode(body), 200, request: request, headers: {'content-type': 'application/json'});
  test('讀取超過 1000 筆自己的紀錄會以完整主鍵排序分頁', () async {
    final offsets = <int>[];
    final client = SupabaseClient(
      'https://test.invalid',
      'public-test-key',
      httpClient: MockClient((request) async {
        final table = request.url.pathSegments.last;
        if (table == 'memberships') {
          return response(request, [
            {
              'starts_on': '2026-10-09',
              'nourish_choice': ['water', 'produce'],
              'version': 1,
            },
          ]);
        }
        if (table != 'checkins') return response(request, []);
        expect(request.url.queryParameters['order'], contains('period_date.desc'));
        expect(request.url.queryParameters['order'], contains('item_id.desc'));
        final offset = int.parse(request.url.queryParameters['offset'] ?? '0');
        offsets.add(offset);
        return response(
          request,
          List.generate(
            offset < 1000 ? 500 : 1,
            (i) => {'period_date': '2026-10-09', 'item_id': 'test-${offset + i}', 'amount': 1, 'version': 1},
          ),
        );
      }),
    );
    final records = await TestRepository(client).fetchOwn();
    expect(records.where((r) => r.table == 'checkins').length, 1001);
    expect(offsets, [0, 500, 1000]);
    await client.dispose();
  });
  test('更新帶入原版本與本人身份，零列回應轉為衝突', () async {
    var reads = 0;
    var patches = 0;
    final client = SupabaseClient(
      'https://test.invalid',
      'public-test-key',
      httpClient: MockClient((request) async {
        expect(request.url.queryParameters['user_id'], 'eq.alice');
        expect(request.url.queryParameters['group_id'], 'eq.group');
        if (request.method == 'PATCH') {
          patches++;
          expect(request.url.queryParameters['version'], 'eq.1');
          expect(jsonDecode(request.body), {'amount': 0, 'version': 1});
          return response(request, []);
        }
        reads++;
        return response(request, [
          {'period_date': '2026-10-09', 'item_id': 'reading', 'amount': 1, 'version': reads == 1 ? 1 : 2},
        ]);
      }),
    );
    final repository = TestRepository(client);
    await expectLater(
      repository.save(const SyncRecord(table: 'checkins', key: '2026-10-09|reading', version: 1, data: {'amount': 0})),
      throwsA(isA<SyncConflict>().having((e) => e.remote.version, 'server version', 2)),
    );
    expect(patches, 1);
    await client.dispose();
  });
  test('伺服器已存在相同內容，重試只讀取不重複寫入', () async {
    final client = SupabaseClient(
      'https://test.invalid',
      'public-test-key',
      httpClient: MockClient((request) async {
        expect(request.method, 'GET');
        return response(request, [
          {'period_date': '2026-10-09', 'item_id': 'reading', 'amount': 0, 'version': 3},
        ]);
      }),
    );
    final saved = await TestRepository(client)
        .save(const SyncRecord(table: 'checkins', key: '2026-10-09|reading', version: 2, data: {'amount': 0}));
    expect(saved.version, 3);
    await client.dispose();
  });
  test('未登入的正式 repository 不會發出任何業務請求', () async {
    final client = SupabaseClient(
      'https://test.invalid',
      'public-test-key',
      httpClient: MockClient((_) async => throw StateError('unexpected request')),
    );
    final repository = CloudRepository(client, userId: 'alice', groupId: 'group');
    await expectLater(repository.fetchOwn(), throwsA(isA<SessionChanged>()));
    await client.dispose();
  });
}
