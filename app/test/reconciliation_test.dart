import 'package:flutter_test/flutter_test.dart';
import 'package:petfy/main.dart';

CodexPetEvent event({
  required String type,
  required String timestamp,
  String? threadId = 'thread-1',
  String? turnId,
}) {
  return CodexPetEvent(
    type: type,
    cwd: '/workspace/petfy',
    projectName: 'petfy',
    message: type,
    timestamp: timestamp,
    threadId: threadId,
    turnId: turnId,
  );
}

void main() {
  final now = DateTime.utc(2026, 7, 27, 15);

  test('completion resolves the same working turn', () {
    final tasks = reconcileCodexPetEvents([
      event(
        type: 'task.started',
        turnId: 'turn-1',
        timestamp: '2026-07-27T14:58:00Z',
      ),
      event(
        type: 'task.completed',
        turnId: 'turn-1',
        timestamp: '2026-07-27T14:59:00Z',
      ),
    ], now: now);

    expect(tasks, hasLength(1));
    expect(tasks.single.type, 'task.completed');
  });

  test('a follow-up turn remains active after an earlier completion', () {
    final tasks = reconcileCodexPetEvents([
      event(
        type: 'task.completed',
        turnId: 'turn-1',
        timestamp: '2026-07-27T14:57:00Z',
      ),
      event(
        type: 'task.started',
        turnId: 'turn-2',
        timestamp: '2026-07-27T14:59:00Z',
      ),
    ], now: now);

    expect(tasks.map((task) => task.type), ['task.started', 'task.completed']);
  });

  test('stale working tasks are not shown', () {
    final tasks = reconcileCodexPetEvents([
      event(
        type: 'task.started',
        turnId: 'turn-1',
        timestamp: '2026-07-27T14:40:00Z',
      ),
    ], now: now);

    expect(tasks, isEmpty);
  });

  test(
    'a completion without turn metadata resolves a matching session task',
    () {
      final tasks = reconcileCodexPetEvents([
        event(
          type: 'task.started',
          turnId: 'turn-1',
          timestamp: '2026-07-27T14:58:00Z',
        ),
        event(
          type: 'task.completed',
          turnId: null,
          timestamp: '2026-07-27T14:59:00Z',
        ),
      ], now: now);

      expect(tasks, hasLength(1));
      expect(tasks.single.type, 'task.completed');
    },
  );
}
