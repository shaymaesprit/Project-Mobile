import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:studymate/data/services/studymate_api.dart';
import 'package:studymate/data/sync/offline_outbox.dart';
import 'package:studymate/data/sync/sync_service.dart';

const uid = 'student-a';

/// Fausse API : enregistre les requêtes, peut simuler une coupure réseau ou
/// un refus du serveur.
class FakeApi extends StudyMateApi {
  FakeApi() : super(tokenProvider: null);

  final requests = <String>[];
  final payloads = <Map<String, dynamic>?>[];
  bool offline = false;
  bool serverDown = false;
  StudyMateApiException? rejectNext;
  int _ids = 0;

  @override
  Future<Map<String, dynamic>?> syncRequest(
    String method,
    String path, {
    Map<String, dynamic>? data,
  }) async {
    if (offline) {
      throw const StudyMateApiException('offline', isNetworkError: true);
    }
    if (serverDown) {
      throw const StudyMateApiException('Boom', statusCode: 503);
    }
    final rejection = rejectNext;
    if (rejection != null) {
      rejectNext = null;
      throw rejection;
    }
    requests.add('$method $path');
    payloads.add(data);
    if (method == 'POST') return {...?data, 'id': 'srv-${++_ids}'};
    return data;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late OfflineOutbox outbox;
  late FakeApi api;
  late StreamController<List<ConnectivityResult>> network;
  late SyncService sync;

  setUp(() {
    outbox = OfflineOutbox.inMemory();
    api = FakeApi();
    network = StreamController<List<ConnectivityResult>>.broadcast();
    sync = SyncService(
      api: api,
      userIdProvider: () => uid,
      outbox: outbox,
      connectivity: network.stream,
    );
  });

  tearDown(() async {
    sync.dispose();
    await network.close();
  });

  group('fusion des opérations en attente', () {
    test('créer puis modifier hors ligne → une seule création à jour', () async {
      await outbox.enqueue(
        userId: uid,
        entity: 'task',
        op: OutboxOp.create,
        entityId: 'local-1',
        payload: {'title': 'Réviser', 'priority': 'medium'},
      );
      await outbox.enqueue(
        userId: uid,
        entity: 'task',
        op: OutboxOp.update,
        entityId: 'local-1',
        payload: {'is_completed': true},
      );

      final pending = await outbox.pending(uid);
      expect(pending, hasLength(1));
      expect(pending.single.op, OutboxOp.create);
      expect(pending.single.payload, {
        'title': 'Réviser',
        'priority': 'medium',
        'is_completed': true,
      });
    });

    test('créer puis supprimer hors ligne → rien à envoyer', () async {
      await outbox.enqueue(
        userId: uid,
        entity: 'note',
        op: OutboxOp.create,
        entityId: 'local-2',
        payload: {'title': 'Brouillon'},
      );
      await outbox.enqueue(
        userId: uid,
        entity: 'note',
        op: OutboxOp.delete,
        entityId: 'local-2',
      );
      expect(await outbox.count(uid), 0);
    });

    test('modifier puis supprimer → seulement la suppression', () async {
      await outbox.enqueue(
        userId: uid,
        entity: 'course',
        op: OutboxOp.update,
        entityId: 'c1',
        payload: {'title': 'Maths'},
      );
      await outbox.enqueue(
        userId: uid,
        entity: 'course',
        op: OutboxOp.delete,
        entityId: 'c1',
      );
      final pending = await outbox.pending(uid);
      expect(pending.single.op, OutboxOp.delete);
    });

    test('les opérations sont isolées par utilisateur', () async {
      await outbox.enqueue(
        userId: 'student-b',
        entity: 'task',
        op: OutboxOp.delete,
        entityId: 't9',
      );
      expect(await outbox.count(uid), 0);
      await outbox.purgeOtherUsers(uid);
      expect(await outbox.count('student-b'), 0);
    });
  });

  group('synchronisation', () {
    test('hors ligne : rien n’est perdu, tout part au retour du réseau', () async {
      api.offline = true;
      await sync.enqueue(
        entity: 'task',
        op: OutboxOp.create,
        entityId: 'local-1',
        payload: {'title': 'Exposé'},
      );
      await sync.flush();
      expect(sync.pendingCount, 1);
      expect(sync.isOnline, isFalse);
      expect(api.requests, isEmpty);

      api.offline = false;
      expect(await sync.flush(), isTrue);
      expect(sync.pendingCount, 0);
      expect(api.requests, ['POST /tasks']);
    });

    test('ordre respecté et identifiants locaux remplacés partout', () async {
      api.offline = true;
      final created = <String>[];
      sync.onCreated((entity, localId, json) async => created.add('$localId→${json['id']}'));

      await sync.enqueue(
        entity: 'course',
        op: OutboxOp.create,
        entityId: 'local-c',
        payload: {'title': 'Physique'},
      );
      await sync.enqueue(
        entity: 'task',
        op: OutboxOp.create,
        entityId: 'local-t',
        payload: {'title': 'TP', 'course_id': 'local-c'},
      );
      await sync.enqueue(
        entity: 'course',
        op: OutboxOp.update,
        entityId: 'srv-existing',
        payload: {'title': 'Chimie'},
      );

      api.offline = false;
      await sync.flush();

      expect(api.requests, ['POST /courses', 'POST /tasks', 'PUT /courses/srv-existing']);
      // La tâche a été envoyée avec l'identifiant serveur du cours.
      expect(api.payloads[1]?['course_id'], 'srv-1');
      expect(created, ['local-c→srv-1', 'local-t→srv-2']);
    });

    test('les événements sont forcés (conflits déjà signalés à l’étudiant)', () async {
      await sync.enqueue(
        entity: 'event',
        op: OutboxOp.create,
        entityId: 'local-e',
        payload: {'title': 'Révision'},
      );
      await sync.enqueue(
        entity: 'event',
        op: OutboxOp.update,
        entityId: 'e1',
        payload: {'status': 'done'},
      );
      await sync.flush();
      expect(api.requests, ['POST /events?force=true', 'PUT /events/e1?force=true']);
    });

    test('refus du serveur : opération retirée et signalée, la suite continue', () async {
      final rejected = <String>[];
      sync.onRejected((entry, message) async => rejected.add('${entry.entity}:$message'));
      api.rejectNext = const StudyMateApiException(
        'Ce cours chevauche un autre cours.',
        statusCode: 409,
      );

      await sync.enqueue(
        entity: 'course',
        op: OutboxOp.create,
        entityId: 'local-x',
        payload: {'title': 'Doublon'},
      );
      await sync.enqueue(
        entity: 'note',
        op: OutboxOp.create,
        entityId: 'local-n',
        payload: {'title': 'Ok'},
      );
      await sync.flush();

      expect(rejected, ['course:Ce cours chevauche un autre cours.']);
      expect(sync.takeLastRejection(), contains('refusée'));
      expect(api.requests, ['POST /notes']);
      expect(sync.pendingCount, 0);
    });

    test('élément déjà supprimé sur le serveur (404) : ignoré sans erreur', () async {
      final rejected = <String>[];
      sync.onRejected((entry, message) async => rejected.add(message));
      api.rejectNext = const StudyMateApiException('Not found', statusCode: 404);
      await sync.enqueue(entity: 'task', op: OutboxOp.delete, entityId: 't1');
      await sync.flush();
      expect(rejected, isEmpty);
      expect(sync.pendingCount, 0);
    });

    test('erreur serveur 5xx : on garde l’opération pour plus tard', () async {
      api.serverDown = true;
      await sync.enqueue(entity: 'note', op: OutboxOp.delete, entityId: 'n1');
      await sync.flush();
      expect(sync.pendingCount, 1);
      api.serverDown = false;
      await sync.flush();
      expect(sync.pendingCount, 0);
    });

    test('le retour du réseau déclenche la synchronisation', () async {
      api.offline = true;
      await sync.enqueue(entity: 'note', op: OutboxOp.delete, entityId: 'n1');
      await sync.flush();
      expect(sync.pendingCount, 1);

      api.offline = false;
      network.add([ConnectivityResult.wifi]);
      await Future<void>.delayed(const Duration(milliseconds: 200));
      expect(sync.pendingCount, 0);
      expect(api.requests, ['DELETE /notes/n1']);
    });
  });
}
