import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'panel_theme.dart';

void main() {
  runApp(const CodexPetApp());
}

class CodexPetApp extends StatelessWidget {
  const CodexPetApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Petfy',
      color: Colors.transparent,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0F766E),
          brightness: Brightness.light,
        ),
        canvasColor: Colors.transparent,
        scaffoldBackgroundColor: Colors.transparent,
        useMaterial3: true,
      ),
      home: const PetHomePage(),
    );
  }
}

class PetHomePage extends StatefulWidget {
  const PetHomePage({super.key});

  @override
  State<PetHomePage> createState() => _PetHomePageState();
}

class _PetHomePageState extends State<PetHomePage> {
  final List<CodexPetEvent> _tasks = <CodexPetEvent>[];
  Timer? _refreshTimer;
  bool _refreshInFlight = false;
  DateTime? _lastSessionScanAt;
  List<CodexPetEvent> _cachedActiveSessionEvents = const <CodexPetEvent>[];
  String? _error;
  bool _loading = true;
  bool _panelOpen = false;
  String? _focusingKey;
  String? _lastSoundEventKey;
  bool _soundPrimed = false;
  _PanelView _panelView = _PanelView.activity;
  bool _repairingSetup = false;
  bool _soundsEnabled = true;
  bool _completedSoundEnabled = true;
  bool _attentionSoundEnabled = true;
  bool _autoClearCompleted = false;
  int _autoClearCompletedAfterMinutes = 10;
  bool _showEventLog = false;
  bool _showDebugLog = false;
  bool _showPetBubble = false;
  bool _animationsEnabled = true;
  _PetfyMascot _mascot = _PetfyMascot.pug;
  int _petSize = 112;
  String _startupPosition = 'remember';
  bool _darkPanel = false;
  bool _launchAtLoginEnabled = false;
  bool _setupGuideDismissed = false;
  bool _checkingForUpdates = false;
  String _updateFeedUrl = ProjectPaths.defaultUpdateFeedUrl;
  UpdateCheckResult? _updateStatus;
  bool _settingsLoaded = false;
  PopoverPlacement _popoverPlacement = PopoverPlacement.leftDown;
  List<SetupDiagnostic> _diagnostics = const <SetupDiagnostic>[];
  List<EventLogEntry> _eventLog = const <EventLogEntry>[];
  List<DebugLogEntry> _debugLog = const <DebugLogEntry>[];

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _refreshLaunchAtLogin();
    _loadTasks();
    _loadDiagnostics(includeNodeCheck: false);
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 2),
      (_) => _loadTasks(silent: true),
    );
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final file = File(ProjectPaths.settingsFile);
    if (!await file.exists()) {
      if (mounted) {
        setState(() => _settingsLoaded = true);
        await _maybeOpenSetupGuide(_diagnostics);
      }
      return;
    }

    try {
      final json =
          jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      if (!mounted) {
        return;
      }
      setState(() {
        _soundsEnabled = json['soundsEnabled'] != false;
        _completedSoundEnabled = json['completedSoundEnabled'] != false;
        _attentionSoundEnabled = json['attentionSoundEnabled'] != false;
        _autoClearCompleted = json['autoClearCompleted'] == true;
        _autoClearCompletedAfterMinutes = _readAutoClearMinutes(
          json['autoClearCompletedAfterMinutes'],
        );
        _showEventLog = json['showEventLog'] == true;
        _showDebugLog = json['showDebugLog'] == true;
        _showPetBubble = json['showPetBubble'] == true;
        _animationsEnabled = json['animationsEnabled'] != false;
        _mascot = _PetfyMascot.fromStored(json['mascot']);
        _petSize = _readPetSize(json['petSize']);
        _startupPosition = _readStartupPosition(json['startupPosition']);
        _darkPanel = json['darkPanel'] == true;
        _setupGuideDismissed = json['setupGuideDismissed'] == true;
        _updateFeedUrl =
            json['updateFeedUrl']?.toString() ??
            ProjectPaths.defaultUpdateFeedUrl;
        _settingsLoaded = true;
      });
      WindowController.setStartupPosition(_startupPosition);
      await _maybeOpenSetupGuide(_diagnostics);
    } on Object {
      if (mounted) {
        setState(() => _settingsLoaded = true);
      }
      return;
    }
  }

  Future<void> _saveSettings() async {
    final file = File(ProjectPaths.settingsFile);
    await file.parent.create(recursive: true);
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert({
        'soundsEnabled': _soundsEnabled,
        'completedSoundEnabled': _completedSoundEnabled,
        'attentionSoundEnabled': _attentionSoundEnabled,
        'autoClearCompleted': _autoClearCompleted,
        'autoClearCompletedAfterMinutes': _autoClearCompletedAfterMinutes,
        'showEventLog': _showEventLog,
        'showDebugLog': _showDebugLog,
        'showPetBubble': _showPetBubble,
        'animationsEnabled': _animationsEnabled,
        'mascot': _mascot.id,
        'petSize': _petSize,
        'startupPosition': _startupPosition,
        'darkPanel': _darkPanel,
        'setupGuideDismissed': _setupGuideDismissed,
        'updateFeedUrl': _updateFeedUrl,
      }),
    );
  }

  void _refreshLaunchAtLogin() {
    final enabled = File(ProjectPaths.launchAgentFile).existsSync();
    if (!mounted) {
      _launchAtLoginEnabled = enabled;
      return;
    }
    setState(() => _launchAtLoginEnabled = enabled);
  }

  int _readAutoClearMinutes(Object? value) {
    final parsed = value is num ? value.round() : int.tryParse('$value');
    if (parsed == null) {
      return 10;
    }
    return parsed.clamp(1, 120);
  }

  int _readPetSize(Object? value) {
    final parsed = value is num ? value.round() : int.tryParse('$value');
    if (parsed == null) {
      return 112;
    }
    return parsed.clamp(80, 136);
  }

  String _readStartupPosition(Object? value) {
    final text = value?.toString();
    return _SelectOption.isValid(text) ? text! : 'remember';
  }

  Future<void> _loadEventLog() async {
    final historyFile = File(ProjectPaths.historyFile);
    final entries = <EventLogEntry>[];

    if (await historyFile.exists()) {
      final lines = await historyFile.readAsLines();
      for (final line in lines.reversed) {
        final trimmed = line.trim();
        if (trimmed.isEmpty) {
          continue;
        }
        entries.add(EventLogEntry.fromRawJson(trimmed));
        if (entries.length >= 30) {
          break;
        }
      }
    }

    final latestFile = File(ProjectPaths.latestEventFile);
    if (entries.isEmpty && await latestFile.exists()) {
      final raw = await latestFile.readAsString();
      if (raw.trim().isNotEmpty) {
        entries.add(EventLogEntry.fromRawJson(raw));
      }
    }

    if (!mounted) {
      return;
    }
    setState(() => _eventLog = entries);
  }

  Future<void> _loadDebugLog() async {
    final sources = <String, String>{
      'bridge.log': ProjectPaths.bridgeLogFile,
      'notify.log': ProjectPaths.notifyLogFile,
      'petfy.out.log': ProjectPaths.stdoutLog,
      'petfy.err.log': ProjectPaths.stderrLog,
      'events.jsonl': ProjectPaths.historyFile,
    };
    final entries = <DebugLogEntry>[];

    for (final source in sources.entries) {
      final file = File(source.value);
      if (!await file.exists()) {
        continue;
      }
      final lines = await file.readAsLines();
      for (final line in lines.reversed.take(12)) {
        final trimmed = line.trim();
        if (trimmed.isEmpty) {
          continue;
        }
        entries.add(
          DebugLogEntry(
            source: source.key,
            path: source.value,
            message: trimmed,
          ),
        );
      }
    }

    if (!mounted) {
      return;
    }
    setState(() {
      _debugLog = entries.take(50).toList(growable: false);
    });
  }

  Future<void> _loadTasks({bool silent = false}) async {
    if (_refreshInFlight) {
      return;
    }
    _refreshInFlight = true;

    if (!silent) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      if (_autoClearCompleted) {
        await _autoClearCompletedEvents();
      }
      final events = await _readEvents();
      _playSoundForNewEvent(events);
      if (!mounted) {
        return;
      }

      final changed = !_sameTaskSnapshot(events);
      if (changed || !silent || _loading || _error != null) {
        setState(() {
          _tasks
            ..clear()
            ..addAll(events);
          _loading = false;
          _error = null;
        });
      }
      if (_panelOpen && changed) {
        await WindowController.setExpanded(
          true,
          height: _expandedWindowHeight(taskCount: events.length),
          placement: _popoverPlacement,
        );
      }
    } on Object catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _error = error.toString();
        _loading = false;
      });
    } finally {
      _refreshInFlight = false;
    }
  }

  bool _sameTaskSnapshot(List<CodexPetEvent> next) {
    if (_tasks.length != next.length) {
      return false;
    }
    for (var index = 0; index < next.length; index += 1) {
      final current = _tasks[index];
      final incoming = next[index];
      if (current.taskKey != incoming.taskKey ||
          current.type != incoming.type ||
          current.timestamp != incoming.timestamp ||
          current.message != incoming.message) {
        return false;
      }
    }
    return true;
  }

  Future<void> _loadDiagnostics({bool includeNodeCheck = true}) async {
    final diagnostics = <SetupDiagnostic>[];

    diagnostics.add(
      SetupDiagnostic(
        label: 'Runtime',
        ok: Directory(ProjectPaths.repoRoot).existsSync(),
        detail: ProjectPaths.repoRoot,
      ),
    );
    diagnostics.add(
      SetupDiagnostic(
        label: 'Bridge',
        ok: File(ProjectPaths.bridgeCli).existsSync(),
        detail: ProjectPaths.bridgeCli,
      ),
    );
    diagnostics.add(
      SetupDiagnostic(
        label: 'Hook script',
        ok: File(ProjectPaths.hookScript).existsSync(),
        detail: ProjectPaths.hookScript,
      ),
    );
    diagnostics.add(
      SetupDiagnostic(
        label: 'State dir',
        ok: Directory(ProjectPaths.stateDir).existsSync(),
        detail: ProjectPaths.stateDir,
      ),
    );
    diagnostics.add(
      SetupDiagnostic(
        label: 'Settings',
        ok: true,
        detail: ProjectPaths.settingsFile,
      ),
    );
    diagnostics.add(
      SetupDiagnostic(
        label: 'Update feed',
        ok: _updateFeedUrl.isNotEmpty,
        detail: _updateFeedUrl.isEmpty
            ? 'No update feed configured'
            : _updateFeedUrl,
      ),
    );
    diagnostics.add(
      includeNodeCheck
          ? await _nodeDiagnostic()
          : SetupDiagnostic(
              label: 'Node.js',
              ok: true,
              detail: 'Checked when diagnostics opens',
            ),
    );
    diagnostics.add(await _hooksDiagnostic());
    diagnostics.add(await _notifyDiagnostic());
    diagnostics.add(await _sessionScanDiagnostic());

    if (Platform.isMacOS) {
      diagnostics.add(
        SetupDiagnostic(
          label: 'Login item',
          ok: File(ProjectPaths.launchAgentFile).existsSync(),
          detail: ProjectPaths.launchAgentFile,
        ),
      );
    }

    if (!mounted) {
      return;
    }

    setState(() => _diagnostics = diagnostics);
    await _maybeOpenSetupGuide(diagnostics);
  }

  Future<void> _maybeOpenSetupGuide(List<SetupDiagnostic> diagnostics) async {
    final setupHealthy =
        diagnostics.isNotEmpty &&
        diagnostics.every((diagnostic) => diagnostic.ok);
    if (!_settingsLoaded ||
        diagnostics.isEmpty ||
        setupHealthy ||
        _setupGuideDismissed ||
        _panelOpen) {
      return;
    }

    final placement = await WindowController.popoverPlacement();
    if (!mounted) {
      return;
    }
    setState(() {
      _popoverPlacement = placement;
      _panelView = _PanelView.setup;
      _panelOpen = true;
    });
    await WindowController.setExpanded(
      true,
      height: _expandedWindowHeight(),
      placement: placement,
    );
  }

  Future<SetupDiagnostic> _nodeDiagnostic() async {
    try {
      final result = await Process.run(ProjectPaths.nodeBinary, ['--version']);
      return SetupDiagnostic(
        label: 'Node.js',
        ok: result.exitCode == 0,
        detail: result.exitCode == 0
            ? '${ProjectPaths.nodeBinary} ${result.stdout.toString().trim()}'
            : result.stderr.toString().trim(),
      );
    } on Object catch (error) {
      return SetupDiagnostic(
        label: 'Node.js',
        ok: false,
        detail: error.toString(),
      );
    }
  }

  Future<SetupDiagnostic> _hooksDiagnostic() async {
    final hooksFile = File(ProjectPaths.codexHooksFile);
    if (!await hooksFile.exists()) {
      return SetupDiagnostic(
        label: 'Codex hooks',
        ok: false,
        detail: ProjectPaths.codexHooksFile,
      );
    }

    final content = await hooksFile.readAsString();
    final hasPetfyHook = content.contains('petfy-event.sh');
    return SetupDiagnostic(
      label: 'Codex hooks',
      ok: hasPetfyHook,
      detail: hasPetfyHook ? 'Petfy hooks installed' : 'No Petfy hook found',
    );
  }

  Future<SetupDiagnostic> _notifyDiagnostic() async {
    final configFile = File(ProjectPaths.codexConfigFile);
    if (!await configFile.exists()) {
      return SetupDiagnostic(
        label: 'Codex notify',
        ok: false,
        detail: ProjectPaths.codexConfigFile,
      );
    }

    final content = await configFile.readAsString();
    final hasNotify = content.contains('petfy-notify.sh');
    return SetupDiagnostic(
      label: 'Codex notify',
      ok: hasNotify,
      detail: hasNotify ? 'Petfy notify installed' : 'Petfy notify missing',
    );
  }

  Future<SetupDiagnostic> _sessionScanDiagnostic() async {
    final sessionsDir = Directory(ProjectPaths.codexSessionsDir);
    if (!await sessionsDir.exists()) {
      return SetupDiagnostic(
        label: 'Session scan',
        ok: false,
        detail: ProjectPaths.codexSessionsDir,
      );
    }

    final hasSessions = await sessionsDir
        .list(recursive: true, followLinks: false)
        .any((entity) => entity is File && entity.path.endsWith('.jsonl'));

    return SetupDiagnostic(
      label: 'Session scan',
      ok: hasSessions,
      detail: hasSessions
          ? 'Watching Codex sessions for running tasks'
          : ProjectPaths.codexSessionsDir,
    );
  }

  Future<void> _repairSetup() async {
    setState(() => _repairingSetup = true);
    try {
      final result = await Process.run(ProjectPaths.nodeBinary, [
        ProjectPaths.installCodexScript,
      ], workingDirectory: ProjectPaths.repoRoot);

      if (result.exitCode != 0 && mounted) {
        setState(() => _error = result.stderr.toString());
      } else {
        final output = result.stdout.toString().trim();
        if (output.isNotEmpty) {
          final json = jsonDecode(output) as Map<String, dynamic>;
          if (json['ok'] != true && mounted) {
            final reason =
                json['reason']?.toString() ?? 'Unable to focus project';
            final attempted = json['attempted'] is List
                ? (json['attempted'] as List).join(', ')
                : '';
            setState(() {
              _error = attempted.isEmpty
                  ? reason
                  : '$reason. Tried: $attempted';
            });
          }
        }
      }
    } on Object catch (error) {
      if (mounted) {
        setState(() => _error = error.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _repairingSetup = false);
      }
    }
    await _loadDiagnostics();
  }

  Future<void> _autoClearCompletedEvents() async {
    final historyFile = File(ProjectPaths.historyFile);
    final latestFile = File(ProjectPaths.latestEventFile);
    if (!await historyFile.exists()) {
      return;
    }

    final cutoff = DateTime.now().toUtc().subtract(
      Duration(minutes: _autoClearCompletedAfterMinutes),
    );
    final remainingJson = <Map<String, dynamic>>[];

    for (final line in await historyFile.readAsLines()) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) {
        continue;
      }
      final json = jsonDecode(trimmed) as Map<String, dynamic>;
      final event = CodexPetEvent.fromJson(json);
      final expiredCompleted =
          event.type == 'task.completed' && event.occurredAt.isBefore(cutoff);
      if (!expiredCompleted) {
        remainingJson.add(json);
      }
    }

    if (remainingJson.isEmpty) {
      await historyFile.delete();
      if (await latestFile.exists()) {
        await latestFile.delete();
      }
      return;
    }

    await historyFile.writeAsString(
      '${remainingJson.map(jsonEncode).join('\n')}\n',
    );
    await latestFile.writeAsString(
      const JsonEncoder.withIndent('  ').convert(remainingJson.last),
    );
  }

  Future<List<CodexPetEvent>> _readEvents() async {
    final events = <CodexPetEvent>[];
    final historyFile = File(ProjectPaths.historyFile);

    if (await historyFile.exists()) {
      final lines = await historyFile.readAsLines();
      for (final line in lines.reversed) {
        final trimmed = line.trim();
        if (trimmed.isEmpty) {
          continue;
        }
        final json = jsonDecode(trimmed) as Map<String, dynamic>;
        events.add(CodexPetEvent.fromJson(json));
      }
    }

    final latestFile = File(ProjectPaths.latestEventFile);
    if (events.isEmpty && await latestFile.exists()) {
      final json =
          jsonDecode(await latestFile.readAsString()) as Map<String, dynamic>;
      events.add(CodexPetEvent.fromJson(json));
    }

    events.addAll(await _readActiveSessionEvents());

    events.sort((left, right) => right.occurredAt.compareTo(left.occurredAt));

    final distinct = <String, CodexPetEvent>{};
    for (final event in events) {
      // Events are newest first. A later event for the same turn resolves an
      // older working or approval state without affecting other turns in the
      // same workspace.
      distinct.putIfAbsent(event.taskKey, () => event);
    }

    final ordered = distinct.values.toList()
      ..sort((left, right) => right.occurredAt.compareTo(left.occurredAt));
    return ordered.take(8).toList(growable: false);
  }

  Future<List<CodexPetEvent>> _readActiveSessionEvents() async {
    final now = DateTime.now().toUtc();
    final lastScanAt = _lastSessionScanAt;
    if (lastScanAt != null &&
        now.difference(lastScanAt) < const Duration(seconds: 6)) {
      return _cachedActiveSessionEvents;
    }

    final sessionsDir = Directory(ProjectPaths.codexSessionsDir);
    if (!await sessionsDir.exists()) {
      return const [];
    }

    final activeEvents = <CodexPetEvent>[];
    final cutoff = now.subtract(const Duration(hours: 8));
    final staleCutoff = now.subtract(const Duration(minutes: 15));
    final candidates = <(File, FileStat)>[];

    await for (final entity in sessionsDir.list(
      recursive: true,
      followLinks: false,
    )) {
      if (entity is! File || !entity.path.endsWith('.jsonl')) {
        continue;
      }
      final stat = await entity.stat();
      if (!stat.modified.toUtc().isBefore(staleCutoff)) {
        candidates.add((entity, stat));
      }
    }

    candidates.sort(
      (left, right) => right.$2.modified.compareTo(left.$2.modified),
    );

    for (final candidate in candidates.take(12)) {
      final file = candidate.$1;
      final modifiedAt = candidate.$2.modified.toUtc();
      final active = await _activeEventFromSession(file, cutoff, modifiedAt);
      if (active != null) {
        activeEvents.add(active);
      }
    }

    _lastSessionScanAt = now;
    _cachedActiveSessionEvents = List.unmodifiable(activeEvents);
    return _cachedActiveSessionEvents;
  }

  Future<CodexPetEvent?> _activeEventFromSession(
    File file,
    DateTime cutoff,
    DateTime fileModifiedAt,
  ) async {
    String? cwd;
    String? sessionId;
    var source = 'codex';
    var isAuxiliarySession = false;
    final startedAtByTurn = <String, String>{};
    final promptByTurn = <String, String>{};
    final completedTurns = <String>{};
    final touchedAtByTurn = <String, String>{};
    String? currentTurnId;
    String? currentPrompt;

    for (final line in await _readRelevantSessionLines(file)) {
      if (line.trim().isEmpty) {
        continue;
      }

      final entry = _tryDecodeSessionLine(line);
      if (entry == null) {
        continue;
      }
      final timestamp = entry['timestamp']?.toString();
      final payload = entry['payload'] is Map<String, dynamic>
          ? entry['payload'] as Map<String, dynamic>
          : const <String, dynamic>{};

      if (entry['type'] == 'session_meta') {
        sessionId =
            payload['session_id']?.toString() ?? payload['id']?.toString();
        cwd = payload['cwd']?.toString() ?? cwd;
        isAuxiliarySession = payload['source'] is Map<String, dynamic>;
        source = _sourceFromSessionMeta(payload);
      }

      if (entry['type'] == 'turn_context') {
        currentTurnId = payload['turn_id']?.toString() ?? currentTurnId;
        cwd = payload['cwd']?.toString() ?? cwd;
      }

      if (entry['type'] == 'event_msg') {
        final eventType = payload['type']?.toString();
        final turnId = _turnIdFromPayload(payload, currentTurnId, sessionId);
        if (turnId != null && turnId.isNotEmpty) {
          currentTurnId = turnId;
          touchedAtByTurn[turnId] =
              timestamp ?? DateTime.now().toUtc().toIso8601String();
        }
        if (eventType == 'user_message') {
          currentPrompt = payload['message']?.toString() ?? currentPrompt;
          if (turnId != null && turnId.isNotEmpty) {
            startedAtByTurn.putIfAbsent(
              turnId,
              () => timestamp ?? DateTime.now().toUtc().toIso8601String(),
            );
            promptByTurn[turnId] = currentPrompt ?? '';
          }
        } else if (eventType == 'task_started') {
          if (turnId != null && turnId.isNotEmpty) {
            startedAtByTurn[turnId] =
                timestamp ?? DateTime.now().toUtc().toIso8601String();
            if (currentPrompt != null) {
              promptByTurn[turnId] = currentPrompt;
            }
          }
        } else if (_isTurnCompletionEvent(eventType)) {
          if (turnId != null && turnId.isNotEmpty) {
            completedTurns.add(turnId);
          }
        }
      }

      if (entry['type'] == 'response_item') {
        final turnId = _turnIdFromPayload(payload, currentTurnId, sessionId);
        if (turnId != null && turnId.isNotEmpty) {
          currentTurnId = turnId;
          startedAtByTurn.putIfAbsent(
            turnId,
            () => timestamp ?? DateTime.now().toUtc().toIso8601String(),
          );
          touchedAtByTurn[turnId] =
              timestamp ?? DateTime.now().toUtc().toIso8601String();
          final phase = payload['phase']?.toString();
          if (phase == 'final_answer') {
            completedTurns.add(turnId);
          }
        }
      }
    }

    if (isAuxiliarySession) {
      return null;
    }

    final activeTurnIds = startedAtByTurn.keys.where((turnId) {
      if (completedTurns.contains(turnId)) {
        return false;
      }
      final touchedAt = DateTime.tryParse(
        touchedAtByTurn[turnId] ?? startedAtByTurn[turnId] ?? '',
      );
      if (touchedAt == null) {
        return true;
      }
      return !touchedAt.toUtc().isBefore(
        DateTime.now().toUtc().subtract(const Duration(minutes: 15)),
      );
    }).toList();
    activeTurnIds.sort((left, right) {
      final leftStarted = DateTime.tryParse(startedAtByTurn[left] ?? '');
      final rightStarted = DateTime.tryParse(startedAtByTurn[right] ?? '');
      return (rightStarted ?? DateTime.fromMillisecondsSinceEpoch(0)).compareTo(
        leftStarted ?? DateTime.fromMillisecondsSinceEpoch(0),
      );
    });

    if (activeTurnIds.isEmpty || cwd == null || cwd.isEmpty) {
      return null;
    }

    final startedTurnId = activeTurnIds.first;
    final startedAt = startedAtByTurn[startedTurnId];
    final parsedStartedAt = DateTime.tryParse(startedAt ?? '');
    if (parsedStartedAt == null || parsedStartedAt.toUtc().isBefore(cutoff)) {
      return null;
    }

    return CodexPetEvent(
      type: 'task.started',
      cwd: cwd,
      projectName: cwd.split(Platform.pathSeparator).last,
      message: _shortPrompt(promptByTurn[startedTurnId]),
      timestamp: startedAt ?? fileModifiedAt.toIso8601String(),
      threadId: sessionId,
      turnId: startedTurnId,
      source: source,
    );
  }

  Future<List<String>> _readRelevantSessionLines(File file) async {
    const prefixLength = 64 * 1024;
    const tailLength = 256 * 1024;
    final length = await file.length();
    if (length <= prefixLength + tailLength) {
      return file.readAsLines();
    }

    final prefix = await _readFileSlice(file, 0, prefixLength);
    final tail = await _readFileSlice(file, length - tailLength, tailLength);
    return '$prefix\n$tail'.split('\n');
  }

  Future<String> _readFileSlice(File file, int offset, int length) async {
    final handle = await file.open();
    try {
      await handle.setPosition(offset);
      final bytes = await handle.read(length);
      return utf8.decode(bytes, allowMalformed: true);
    } finally {
      await handle.close();
    }
  }

  Map<String, dynamic>? _tryDecodeSessionLine(String line) {
    try {
      final decoded = jsonDecode(line);
      return decoded is Map<String, dynamic> ? decoded : null;
    } on FormatException {
      return null;
    }
  }

  String? _turnIdFromPayload(
    Map<String, dynamic> payload,
    String? currentTurnId,
    String? sessionId,
  ) {
    final direct =
        payload['turn_id']?.toString() ??
        payload['turnId']?.toString() ??
        payload['turn-id']?.toString();
    if (direct != null && direct.isNotEmpty) {
      return direct;
    }

    final metadata = payload['internal_chat_message_metadata_passthrough'];
    if (metadata is Map<String, dynamic>) {
      final metadataTurnId =
          metadata['turn_id']?.toString() ??
          metadata['turnId']?.toString() ??
          metadata['turn-id']?.toString();
      if (metadataTurnId != null && metadataTurnId.isNotEmpty) {
        return metadataTurnId;
      }
    }

    if (currentTurnId != null && currentTurnId.isNotEmpty) {
      return currentTurnId;
    }
    return sessionId;
  }

  bool _isTurnCompletionEvent(String? eventType) {
    return switch (eventType) {
      'task_complete' ||
      'task_completed' ||
      'turn_complete' ||
      'turn_completed' ||
      'agent_turn_complete' ||
      'agent-turn-complete' ||
      'turn_aborted' ||
      'turn_cancelled' ||
      'turn_canceled' ||
      'error' => true,
      _ => false,
    };
  }

  String _sourceFromSessionMeta(Map<String, dynamic> payload) {
    final rawSource = payload['source'];
    final sourceText = rawSource is String ? rawSource.toLowerCase() : '';
    final originator = payload['originator']?.toString().toLowerCase() ?? '';

    if (sourceText.contains('vscode') || originator.contains('vscode')) {
      return 'vscode';
    }
    if (sourceText.contains('desktop') || originator.contains('desktop')) {
      return 'desktop';
    }
    if (sourceText.contains('cli') || originator.contains('cli')) {
      return 'cli';
    }
    return 'codex';
  }

  String _shortPrompt(String? value) {
    final cleaned = value?.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (cleaned == null || cleaned.isEmpty) {
      return 'Codex is working.';
    }
    return cleaned.length <= 120 ? cleaned : '${cleaned.substring(0, 117)}...';
  }

  void _playSoundForNewEvent(List<CodexPetEvent> events) {
    if (events.isEmpty) {
      return;
    }

    final latest = events.first;
    final soundKey = latest.soundKey;
    if (!_soundPrimed) {
      _soundPrimed = true;
      _lastSoundEventKey = soundKey;
      return;
    }

    if (_lastSoundEventKey == soundKey) {
      return;
    }

    _lastSoundEventKey = soundKey;
    if (!_soundsEnabled) {
      return;
    }

    if (latest.needsAttention && _attentionSoundEnabled) {
      WindowController.playSound(PetSound.attention);
    } else if (latest.type == 'task.completed' && _completedSoundEnabled) {
      WindowController.playSound(PetSound.completed);
    }
  }

  Future<void> _focusProject(CodexPetEvent event) async {
    if (event.cwd.isEmpty) {
      return;
    }

    setState(() => _focusingKey = event.taskKey);
    try {
      final result = await Process.run(ProjectPaths.nodeBinary, [
        ProjectPaths.bridgeCli,
        'focus',
        event.cwd,
      ], workingDirectory: ProjectPaths.repoRoot);

      if (result.exitCode != 0 && mounted) {
        setState(() => _error = result.stderr.toString());
      }
    } on Object catch (error) {
      if (mounted) {
        setState(() => _error = error.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _focusingKey = null);
      }
    }
  }

  Future<void> _clearNotifications() async {
    final latestFile = File(ProjectPaths.latestEventFile);
    final historyFile = File(ProjectPaths.historyFile);

    for (final file in [latestFile, historyFile]) {
      if (await file.exists()) {
        await file.delete();
      }
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _tasks.clear();
      _error = null;
      _panelOpen = false;
      _lastSoundEventKey = null;
      _soundPrimed = false;
    });
    await WindowController.setExpanded(false);
  }

  Future<void> _dismissNotification(CodexPetEvent dismissed) async {
    final historyFile = File(ProjectPaths.historyFile);
    final latestFile = File(ProjectPaths.latestEventFile);
    final remainingJson = <Map<String, dynamic>>[];
    final dismissedTaskKey = dismissed.taskKey;

    setState(() {
      _tasks.removeWhere((task) => task.taskKey == dismissedTaskKey);
    });
    await WindowController.setExpanded(
      true,
      height: _expandedWindowHeight(taskCount: _tasks.length),
      placement: _popoverPlacement,
    );

    if (await historyFile.exists()) {
      final lines = await historyFile.readAsLines();
      for (final line in lines) {
        final trimmed = line.trim();
        if (trimmed.isEmpty) {
          continue;
        }
        final json = jsonDecode(trimmed) as Map<String, dynamic>;
        final event = CodexPetEvent.fromJson(json);
        if (event.taskKey != dismissedTaskKey) {
          remainingJson.add(json);
        }
      }
    }

    if (remainingJson.isEmpty) {
      for (final file in [latestFile, historyFile]) {
        if (await file.exists()) {
          await file.delete();
        }
      }
    } else {
      await historyFile.writeAsString(
        '${remainingJson.map(jsonEncode).join('\n')}\n',
      );
      await latestFile.writeAsString(
        const JsonEncoder.withIndent('  ').convert(remainingJson.last),
      );
    }

    await _loadTasks(silent: true);
  }

  Future<void> _handlePetTap() async {
    await _togglePanel();
  }

  Future<void> _handlePetSecondaryTap() async {
    await _togglePanel();
  }

  Future<void> _togglePanel() async {
    final nextPanelState = !_panelOpen;
    if (nextPanelState) {
      final placement = await WindowController.popoverPlacement();
      if (mounted) {
        setState(() => _popoverPlacement = placement);
      }
      await WindowController.setExpanded(
        true,
        height: _expandedWindowHeight(),
        placement: placement,
      );
      await Future<void>.delayed(const Duration(milliseconds: 16));
      if (!mounted) {
        return;
      }
      setState(() => _panelOpen = true);
      await _loadDiagnostics();
      return;
    }

    setState(() => _panelOpen = false);
    await WindowController.setExpanded(false);
  }

  Future<void> _setLaunchAtLogin(bool enabled) async {
    try {
      if (enabled) {
        await _installLaunchAgent();
        await Process.run('launchctl', [
          'bootstrap',
          'gui/${await _currentUserId()}',
          ProjectPaths.launchAgentFile,
        ]);
        await Process.run('launchctl', [
          'kickstart',
          'gui/${await _currentUserId()}/${ProjectPaths.launchAgentLabel}',
        ]);
      } else {
        await Process.run('launchctl', [
          'bootout',
          'gui/${await _currentUserId()}/${ProjectPaths.launchAgentLabel}',
        ]);
        final file = File(ProjectPaths.launchAgentFile);
        if (await file.exists()) {
          await file.delete();
        }
      }
    } on Object catch (error) {
      if (mounted) {
        setState(() => _error = error.toString());
      }
    } finally {
      _refreshLaunchAtLogin();
      await _loadDiagnostics(includeNodeCheck: false);
    }
  }

  Future<String> _currentUserId() async {
    final result = await Process.run('id', ['-u']);
    if (result.exitCode == 0) {
      return result.stdout.toString().trim();
    }
    return Platform.environment['UID'] ?? '';
  }

  Future<void> _installLaunchAgent() async {
    final file = File(ProjectPaths.launchAgentFile);
    await file.parent.create(recursive: true);
    await Directory(ProjectPaths.stateDir).create(recursive: true);
    await file.writeAsString(ProjectPaths.launchAgentPlist());
  }

  Future<void> _resetPetPosition() async {
    setState(() => _panelOpen = false);
    await WindowController.resetPosition();
  }

  Future<void> _setStartupPosition(String position) async {
    setState(() {
      _startupPosition = position;
      _panelOpen = false;
    });
    await _saveSettings();
    await WindowController.setExpanded(false);
    await WindowController.setStartupPosition(position, move: true);
  }

  Future<void> _checkForUpdates() async {
    if (_checkingForUpdates) {
      return;
    }

    setState(() {
      _checkingForUpdates = true;
      _updateStatus = null;
    });

    try {
      final manifest = await _readUpdateManifest(_updateFeedUrl);
      final latestVersion = manifest['version']?.toString() ?? '';
      final currentVersion = PetfyVersion.current;
      final releaseNotesUrl = manifest['releaseNotesUrl']?.toString();
      final artifact = _artifactForCurrentPlatform(manifest);
      final updateAvailable =
          _compareVersions(latestVersion, currentVersion) > 0;
      final message = updateAvailable
          ? 'Petfy $latestVersion is available.'
          : 'Petfy $currentVersion is up to date.';

      if (!mounted) {
        return;
      }
      setState(() {
        _updateStatus = UpdateCheckResult(
          currentVersion: currentVersion,
          latestVersion: latestVersion.isEmpty ? currentVersion : latestVersion,
          updateAvailable: updateAvailable,
          message: message,
          releaseNotesUrl: releaseNotesUrl,
          artifactUrl: artifact?.url,
          artifactSha256: artifact?.sha256,
          artifactName: artifact?.name,
        );
      });
    } on Object catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _updateStatus = UpdateCheckResult.failure(
          currentVersion: PetfyVersion.current,
          message: error.toString(),
        );
      });
    } finally {
      if (mounted) {
        setState(() => _checkingForUpdates = false);
      }
    }
  }

  Future<Map<String, dynamic>> _readUpdateManifest(String feedUrl) async {
    final trimmed = feedUrl.trim();
    if (trimmed.isEmpty) {
      throw const FormatException('No update feed configured yet.');
    }

    String raw;
    final uri = Uri.tryParse(trimmed);
    if (uri != null && (uri.scheme == 'http' || uri.scheme == 'https')) {
      final client = HttpClient();
      try {
        final request = await client
            .getUrl(uri)
            .timeout(const Duration(seconds: 8));
        final response = await request.close().timeout(
          const Duration(seconds: 8),
        );
        if (response.statusCode < 200 || response.statusCode >= 300) {
          throw HttpException(
            'Update feed returned HTTP ${response.statusCode}',
            uri: uri,
          );
        }
        raw = await utf8.decodeStream(response);
      } finally {
        client.close(force: true);
      }
    } else if (uri != null && uri.scheme == 'file') {
      raw = await File(uri.toFilePath()).readAsString();
    } else {
      raw = await File(trimmed).readAsString();
    }

    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Update feed is not a JSON object.');
    }
    return decoded;
  }

  UpdateArtifact? _artifactForCurrentPlatform(Map<String, dynamic> manifest) {
    final platform = Platform.isMacOS
        ? 'macos'
        : Platform.isWindows
        ? 'windows'
        : Platform.isLinux
        ? 'linux'
        : '';
    final artifacts = manifest['artifacts'];
    if (platform.isEmpty || artifacts is! List) {
      return null;
    }

    for (final artifact in artifacts) {
      if (artifact is! Map<String, dynamic>) {
        continue;
      }
      final artifactPlatform =
          artifact['platform']?.toString() ?? artifact['os']?.toString();
      if (artifactPlatform == platform) {
        return UpdateArtifact(
          name: artifact['name']?.toString() ?? '',
          url: artifact['url']?.toString() ?? '',
          sha256: artifact['sha256']?.toString() ?? '',
        );
      }
    }
    return null;
  }

  int _compareVersions(String left, String right) {
    final leftParts = _versionParts(left);
    final rightParts = _versionParts(right);
    final count = math.max(leftParts.length, rightParts.length);
    for (var index = 0; index < count; index += 1) {
      final leftPart = index < leftParts.length ? leftParts[index] : 0;
      final rightPart = index < rightParts.length ? rightParts[index] : 0;
      if (leftPart != rightPart) {
        return leftPart.compareTo(rightPart);
      }
    }
    return 0;
  }

  List<int> _versionParts(String version) {
    return version
        .split(RegExp(r'[^0-9]+'))
        .where((part) => part.isNotEmpty)
        .map((part) => int.tryParse(part) ?? 0)
        .toList(growable: false);
  }

  Future<void> _openUpdateTarget() async {
    final status = _updateStatus;
    final target = status?.preferredOpenUrl;
    if (target == null || target.isEmpty) {
      return;
    }

    try {
      if (Platform.isMacOS) {
        await Process.run('open', [target]);
      } else if (Platform.isWindows) {
        await Process.run('cmd.exe', ['/c', 'start', '', target]);
      } else {
        await Process.run('xdg-open', [target]);
      }
    } on Object catch (error) {
      if (mounted) {
        setState(() => _error = error.toString());
      }
    }
  }

  double _expandedWindowHeight({int? taskCount}) {
    final count = taskCount ?? _tasks.length;
    const chromeHeight = 112.0 + 10.0 + 54.0 + 28.0;
    final contentHeight = count == 0 ? 112.0 : 12.0 + (count * 86.0);
    final screenHeight = switch (_panelView) {
      _PanelView.activity => contentHeight,
      _PanelView.notifications => contentHeight,
      _PanelView.diagnostics => 330.0,
      _PanelView.settings => 610.0,
      _PanelView.eventLog => 430.0,
      _PanelView.debugLog => 430.0,
      _PanelView.setup => 430.0,
    };
    return math.min(620.0, chromeHeight + screenHeight);
  }

  @override
  Widget build(BuildContext context) {
    final primaryTask = _tasks.isEmpty ? null : _tasks.first;
    final needsAttention = _tasks.any((task) => task.needsAttention);
    final activeTasks = _tasks.where((task) => task.isActive).toList();
    final notificationTasks = _tasks
        .where((task) => task.isNotification)
        .toList();

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: LayoutBuilder(
        builder: (context, constraints) {
          const outerPadding = 14.0;
          final availableWidth = constraints.maxWidth.isFinite
              ? constraints.maxWidth - (outerPadding * 2)
              : 112.0;
          final availableHeight = constraints.maxHeight.isFinite
              ? constraints.maxHeight - (outerPadding * 2)
              : 112.0;
          final petSize = math.max(
            72.0,
            math.min(
              _petSize.toDouble(),
              math.min(availableWidth, availableHeight),
            ),
          );
          final popoverMaxHeight = math.max(
            120.0,
            availableHeight - petSize - 10.0,
          );

          final placement = _popoverPlacement;
          final petButton = _FloatingPetButton(
            size: petSize,
            task: primaryTask,
            taskCount: _tasks.length,
            loading: _loading,
            needsAttention: needsAttention,
            showBubble: _showPetBubble,
            animationsEnabled: _animationsEnabled,
            mascot: _mascot,
            onTap: _handlePetTap,
            onSecondaryTap: _handlePetSecondaryTap,
            onDragStart: WindowController.beginDrag,
            onDragUpdate: WindowController.drag,
          );
          final popover = _TaskPopover(
            activeTasks: activeTasks,
            notificationTasks: notificationTasks,
            error: _error,
            latestEventPath: ProjectPaths.latestEventFile,
            focusingKey: _focusingKey,
            view: _panelView,
            diagnostics: _diagnostics,
            repairingSetup: _repairingSetup,
            soundsEnabled: _soundsEnabled,
            completedSoundEnabled: _completedSoundEnabled,
            attentionSoundEnabled: _attentionSoundEnabled,
            autoClearCompleted: _autoClearCompleted,
            autoClearCompletedAfterMinutes: _autoClearCompletedAfterMinutes,
            showEventLog: _showEventLog,
            showDebugLog: _showDebugLog,
            eventLog: _eventLog,
            debugLog: _debugLog,
            animationsEnabled: _animationsEnabled,
            petSize: _petSize,
            startupPosition: _startupPosition,
            darkPanel: _darkPanel,
            launchAtLoginEnabled: _launchAtLoginEnabled,
            checkingForUpdates: _checkingForUpdates,
            updateFeedUrl: _updateFeedUrl,
            updateStatus: _updateStatus,
            onFocusProject: _focusProject,
            onDismiss: _dismissNotification,
            onRefresh: () => _loadTasks(),
            onRefreshDiagnostics: _loadDiagnostics,
            onClear: _clearNotifications,
            maxHeight: popoverMaxHeight,
            onViewChanged: (view) {
              setState(() => _panelView = view);
              WindowController.setExpanded(
                true,
                height: _expandedWindowHeight(),
                placement: _popoverPlacement,
              );
              if (view == _PanelView.diagnostics) {
                _loadDiagnostics();
              } else if (view == _PanelView.eventLog) {
                _loadEventLog();
              } else if (view == _PanelView.debugLog) {
                _loadDebugLog();
              }
            },
            onSoundsChanged: (value) {
              setState(() => _soundsEnabled = value);
              _saveSettings();
            },
            onCompletedSoundChanged: (value) {
              setState(() => _completedSoundEnabled = value);
              _saveSettings();
            },
            onAttentionSoundChanged: (value) {
              setState(() => _attentionSoundEnabled = value);
              _saveSettings();
            },
            onAutoClearCompletedChanged: (value) {
              setState(() => _autoClearCompleted = value);
              _saveSettings();
              _loadTasks(silent: true);
            },
            onAutoClearCompletedAfterMinutesChanged: (value) {
              setState(() => _autoClearCompletedAfterMinutes = value);
              _saveSettings();
              _loadTasks(silent: true);
            },
            onShowEventLogChanged: (value) {
              setState(() => _showEventLog = value);
              _saveSettings();
              if (!value && _panelView == _PanelView.eventLog) {
                setState(() => _panelView = _PanelView.settings);
              }
            },
            onShowDebugLogChanged: (value) {
              setState(() => _showDebugLog = value);
              _saveSettings();
              if (!value && _panelView == _PanelView.debugLog) {
                setState(() => _panelView = _PanelView.settings);
              }
            },
            showPetBubble: _showPetBubble,
            onShowPetBubbleChanged: (value) {
              setState(() => _showPetBubble = value);
              _saveSettings();
            },
            onAnimationsEnabledChanged: (value) {
              setState(() => _animationsEnabled = value);
              _saveSettings();
            },
            mascot: _mascot,
            onMascotChanged: (value) {
              setState(() => _mascot = value);
              _saveSettings();
            },
            onPetSizeChanged: (value) {
              setState(() => _petSize = value);
              _saveSettings();
            },
            onStartupPositionChanged: _setStartupPosition,
            onDarkPanelChanged: (value) {
              setState(() => _darkPanel = value);
              _saveSettings();
            },
            onLaunchAtLoginChanged: _setLaunchAtLogin,
            onCheckForUpdates: _checkForUpdates,
            onOpenUpdate: _openUpdateTarget,
            onResetPetPosition: _resetPetPosition,
            onRepairSetup: _repairSetup,
            onOpenDiagnostics: () {
              setState(() => _panelView = _PanelView.diagnostics);
              WindowController.setExpanded(
                true,
                height: _expandedWindowHeight(),
                placement: _popoverPlacement,
              );
              _loadDiagnostics();
            },
            onDismissSetupGuide: () {
              setState(() {
                _setupGuideDismissed = true;
                _panelView = _PanelView.activity;
              });
              _saveSettings();
            },
            onQuit: WindowController.quitApp,
          );
          final children = <Widget>[
            if (_panelOpen && placement.opensUp) ...[
              popover,
              const SizedBox(height: 10),
            ],
            petButton,
            if (_panelOpen && !placement.opensUp) ...[
              const SizedBox(height: 10),
              popover,
            ],
          ];

          return Align(
            alignment: placement.alignment,
            child: Padding(
              padding: const EdgeInsets.all(outerPadding),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: placement.crossAxisAlignment,
                children: children,
              ),
            ),
          );
        },
      ),
    );
  }
}

class _FloatingPetButton extends StatefulWidget {
  const _FloatingPetButton({
    required this.size,
    required this.task,
    required this.taskCount,
    required this.loading,
    required this.needsAttention,
    required this.showBubble,
    required this.animationsEnabled,
    required this.mascot,
    required this.onTap,
    required this.onSecondaryTap,
    required this.onDragStart,
    required this.onDragUpdate,
  });

  final double size;
  final CodexPetEvent? task;
  final int taskCount;
  final bool loading;
  final bool needsAttention;
  final bool showBubble;
  final bool animationsEnabled;
  final _PetfyMascot mascot;
  final VoidCallback onTap;
  final VoidCallback onSecondaryTap;
  final VoidCallback onDragStart;
  final VoidCallback onDragUpdate;

  @override
  State<_FloatingPetButton> createState() => _FloatingPetButtonState();
}

class _FloatingPetButtonState extends State<_FloatingPetButton>
    with TickerProviderStateMixin {
  late final AnimationController _controller;
  late final AnimationController _transitionController;
  Timer? _motionTimer;
  _PugMood? _previousMood;
  final _precachedMascots = <_PetfyMascot>{};

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );
    _transitionController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 520),
      value: 1,
    );
    _updateMotionLoop(_currentMood);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _precacheMascot(widget.mascot);
  }

  @override
  void didUpdateWidget(covariant _FloatingPetButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.mascot != widget.mascot) {
      _precacheMascot(widget.mascot);
    }
    final oldMood = _PugMood.fromTask(oldWidget.task, oldWidget.loading);
    final nextMood = _currentMood;
    if (oldMood != nextMood && widget.animationsEnabled) {
      _previousMood = oldMood;
      _transitionController
        ..duration = nextMood.transitionDuration
        ..forward(from: 0);
    }

    _updateMotionLoop(nextMood);
  }

  @override
  void dispose() {
    _motionTimer?.cancel();
    _controller.dispose();
    _transitionController.dispose();
    super.dispose();
  }

  void _precacheMascot(_PetfyMascot mascot) {
    if (!_precachedMascots.add(mascot)) {
      return;
    }
    for (final mood in _PugMood.values) {
      precacheImage(
        ResizeImage.resizeIfNeeded(
          384,
          null,
          AssetImage(mascot.assetPath(mood)),
        ),
        context,
      );
    }
  }

  _PugMood get _currentMood => _PugMood.fromTask(widget.task, widget.loading);

  bool _shouldAnimateContinuously(_PugMood mood) {
    return widget.animationsEnabled &&
        (mood == _PugMood.working || mood == _PugMood.attention);
  }

  void _updateMotionLoop(_PugMood mood) {
    if (!_shouldAnimateContinuously(mood)) {
      _motionTimer?.cancel();
      _motionTimer = null;
      _controller.value = 0;
      return;
    }
    if (_motionTimer != null) {
      return;
    }
    _advanceMotionFrame();
    _motionTimer = Timer.periodic(
      const Duration(milliseconds: 120),
      (_) => _advanceMotionFrame(),
    );
  }

  void _advanceMotionFrame() {
    const cycleMilliseconds = 1600;
    final elapsed = DateTime.now().millisecondsSinceEpoch % cycleMilliseconds;
    _controller.value = elapsed / cycleMilliseconds;
  }

  @override
  Widget build(BuildContext context) {
    final mood = _currentMood;
    final avatarPadding = widget.showBubble
        ? math.max(9.0, widget.size * 0.11)
        : math.max(1.0, widget.size * 0.015);
    final badgeSize = math.max(24.0, widget.size * 0.25);

    return AnimatedBuilder(
      animation: Listenable.merge([_controller, _transitionController]),
      builder: (context, child) {
        final phase = widget.animationsEnabled ? _controller.value : 0.0;
        final entrance = widget.animationsEnabled
            ? mood.entranceTransform(
                _transitionController.value,
                from: _previousMood,
              )
            : _MoodEntranceTransform.none;
        final bob = widget.animationsEnabled ? mood.verticalOffset(phase) : 0.0;
        final pulse = widget.animationsEnabled
            ? widget.needsAttention
                  ? 1.0 + (math.sin(phase * math.pi * 4).abs() * 0.025)
                  : mood.scale(phase)
            : 1.0;
        final rotation = widget.animationsEnabled ? mood.rotation(phase) : 0.0;
        final horizontalOffset = widget.animationsEnabled
            ? mood.horizontalOffset(phase)
            : 0.0;

        return Transform.translate(
          offset: Offset(
            horizontalOffset + entrance.offset.dx,
            bob + entrance.offset.dy,
          ),
          child: Transform.scale(
            scale: pulse * entrance.scale,
            child: Transform.rotate(
              angle: rotation + entrance.rotation,
              child: Tooltip(
                message: 'Petfy',
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: widget.onTap,
                  onSecondaryTap: widget.onSecondaryTap,
                  onPanStart: (_) => widget.onDragStart(),
                  onPanUpdate: (_) => widget.onDragUpdate(),
                  child: MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        SizedBox(
                          width: widget.size,
                          height: widget.size,
                          child: DecoratedBox(
                            decoration: widget.showBubble
                                ? BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.92),
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: const Color(0xFFE2E8F0),
                                    ),
                                    boxShadow: const [
                                      BoxShadow(
                                        color: Color(0x26000000),
                                        blurRadius: 22,
                                        offset: Offset(0, 10),
                                      ),
                                    ],
                                  )
                                : const BoxDecoration(),
                            child: Padding(
                              padding: EdgeInsets.all(avatarPadding),
                              child: _PetAvatar(
                                mascot: widget.mascot,
                                mood: mood,
                                phase: phase,
                                animationsEnabled: widget.animationsEnabled,
                              ),
                            ),
                          ),
                        ),
                        if (widget.taskCount > 1)
                          Positioned(
                            right: 0,
                            bottom: 4,
                            child: _Badge(
                              color: const Color(0xFF0F766E),
                              text: widget.taskCount.toString(),
                              size: badgeSize,
                            ),
                          ),
                        if (widget.needsAttention)
                          Positioned(
                            right: 0,
                            top: 4,
                            child: _Badge(
                              color: const Color(0xFFD97706),
                              text: '!',
                              size: badgeSize,
                            ),
                          ),
                        Positioned(
                          right: 2,
                          bottom: widget.taskCount > 1 ? badgeSize + 4 : 2,
                          child: Container(
                            width: math.max(22, widget.size * 0.22),
                            height: math.max(22, widget.size * 0.22),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.96),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: const Color(0xFFE2E8F0),
                              ),
                            ),
                            child: const Icon(
                              Icons.keyboard_arrow_down,
                              size: 18,
                              color: Color(0xFF334155),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

enum PopoverPlacement {
  leftDown('leftDown'),
  rightDown('rightDown'),
  leftUp('leftUp'),
  rightUp('rightUp');

  const PopoverPlacement(this.nativeValue);

  final String nativeValue;

  bool get opensRight => this == rightDown || this == rightUp;

  bool get opensUp => this == leftUp || this == rightUp;

  Alignment get alignment {
    if (opensUp && opensRight) {
      return Alignment.bottomLeft;
    }
    if (opensUp) {
      return Alignment.bottomRight;
    }
    return opensRight ? Alignment.topLeft : Alignment.topRight;
  }

  CrossAxisAlignment get crossAxisAlignment =>
      opensRight ? CrossAxisAlignment.start : CrossAxisAlignment.end;

  static PopoverPlacement fromNative(Object? value) {
    final text = value?.toString();
    return PopoverPlacement.values.firstWhere(
      (placement) => placement.nativeValue == text,
      orElse: () => PopoverPlacement.leftDown,
    );
  }
}

enum _PugMood {
  idle,
  working,
  completed,
  attention;

  String get assetName {
    return switch (this) {
      _PugMood.idle => 'idle',
      _PugMood.working => 'working',
      _PugMood.completed => 'completed',
      _PugMood.attention => 'attention',
    };
  }

  double verticalOffset(double phase) {
    return switch (this) {
      _PugMood.idle =>
        (math.sin(phase * math.pi * 2) * 1.0) +
            (math.sin((phase * math.pi * 4) + 0.7) * 0.35),
      _PugMood.working =>
        (math.sin(phase * math.pi * 4) * 1.8) +
            (math.sin(phase * math.pi * 2) * 0.8),
      _PugMood.completed =>
        (-math.sin(phase * math.pi * 2).abs() * 3.8) +
            (math.sin(phase * math.pi * 4) * 0.7),
      _PugMood.attention =>
        (math.sin(phase * math.pi * 8) * 1.1) +
            (math.sin(phase * math.pi * 2) * 0.45),
    };
  }

  double horizontalOffset(double phase) {
    return switch (this) {
      _PugMood.attention =>
        (math.sin(phase * math.pi * 10) * 2.1) +
            (math.sin(phase * math.pi * 4) * 0.7),
      _ => 0,
    };
  }

  double scale(double phase) {
    return switch (this) {
      _PugMood.idle => 1.0 + (math.sin(phase * math.pi * 2) * 0.012),
      _PugMood.working => 1.0 + (math.sin(phase * math.pi * 4).abs() * 0.018),
      _PugMood.completed => 1.0 + (math.sin(phase * math.pi * 2).abs() * 0.035),
      _PugMood.attention => 1.0 + (math.sin(phase * math.pi * 6).abs() * 0.025),
    };
  }

  double rotation(double phase) {
    return switch (this) {
      _PugMood.working =>
        (math.sin(phase * math.pi * 4) * 0.034) +
            (math.sin(phase * math.pi * 2) * 0.012),
      _PugMood.attention => math.sin(phase * math.pi * 10) * 0.050,
      _PugMood.completed => math.sin(phase * math.pi * 2) * 0.030,
      _PugMood.idle => math.sin(phase * math.pi * 2) * 0.012,
    };
  }

  Duration get transitionDuration {
    return switch (this) {
      _PugMood.idle => const Duration(milliseconds: 460),
      _PugMood.working => const Duration(milliseconds: 430),
      _PugMood.completed => const Duration(milliseconds: 580),
      _PugMood.attention => const Duration(milliseconds: 420),
    };
  }

  _MoodEntranceTransform entranceTransform(double progress, {_PugMood? from}) {
    final eased = Curves.easeOutCubic.transform(progress);
    final inverse = 1 - eased;
    final lift = math.sin(eased * math.pi);

    return switch (this) {
      _PugMood.idle => _MoodEntranceTransform(
        offset: Offset(0, 4 * inverse),
        scale: 0.98 + (0.02 * eased),
        rotation: 0.025 * inverse,
      ),
      _PugMood.working => _MoodEntranceTransform(
        offset: Offset(0, 6 * inverse),
        scale: 1 + (0.045 * lift),
        rotation: -0.050 * inverse,
      ),
      _PugMood.completed => _MoodEntranceTransform(
        offset: Offset(0, -12 * lift),
        scale: 1 + (0.120 * lift),
        rotation: math.sin(eased * math.pi * 2) * 0.095,
      ),
      _PugMood.attention => _MoodEntranceTransform(
        offset: Offset(math.sin(eased * math.pi * 8) * 5 * inverse, -2 * lift),
        scale: 1 + (0.060 * lift),
        rotation: math.sin(eased * math.pi * 6) * 0.080 * inverse,
      ),
    };
  }

  static _PugMood fromTask(CodexPetEvent? task, bool loading) {
    if (task?.needsAttention ?? false) {
      return _PugMood.attention;
    }
    if (task?.type == 'task.completed') {
      return _PugMood.completed;
    }
    if (task?.type == 'task.started' || loading) {
      return _PugMood.working;
    }
    return _PugMood.idle;
  }
}

enum _PetfyMascot {
  pug('pug', 'Pug'),
  lumo('lumo', 'Lumo'),
  et('classic-et', 'ET', assetId: 'et');

  const _PetfyMascot(this.id, this.label, {String? assetId})
    : assetId = assetId ?? id;

  final String id;
  final String label;
  final String assetId;

  static const options = [
    _SelectOption(value: 'pug', label: 'Pug'),
    _SelectOption(value: 'lumo', label: 'Lumo'),
    _SelectOption(value: 'classic-et', label: 'ET'),
  ];

  static _PetfyMascot fromStored(Object? value) {
    final id = value?.toString();
    // The first alternate mascot used the `et` preference id. Preserve that
    // selection now that the classic ET has its own stable id.
    if (id == 'et') {
      return _PetfyMascot.lumo;
    }
    return _PetfyMascot.values.firstWhere(
      (mascot) => mascot.id == id,
      orElse: () => _PetfyMascot.pug,
    );
  }

  String assetPath(_PugMood mood) =>
      'assets/$assetId/$assetId-${mood.assetName}.png';
}

class _MoodEntranceTransform {
  const _MoodEntranceTransform({
    required this.offset,
    required this.scale,
    required this.rotation,
  });

  static const none = _MoodEntranceTransform(
    offset: Offset.zero,
    scale: 1,
    rotation: 0,
  );

  final Offset offset;
  final double scale;
  final double rotation;
}

class _Badge extends StatelessWidget {
  const _Badge({required this.color, required this.text, required this.size});

  final Color color;
  final String text;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 3),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: Colors.white,
          fontSize: math.max(11, size * 0.46),
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _PetAvatar extends StatelessWidget {
  const _PetAvatar({
    required this.mascot,
    required this.mood,
    required this.phase,
    required this.animationsEnabled,
  });

  final _PetfyMascot mascot;
  final _PugMood mood;
  final double phase;
  final bool animationsEnabled;

  @override
  Widget build(BuildContext context) {
    // The surrounding pet button already animates each mood transition. Keep
    // exactly one PNG in this layer so rapid event changes cannot stack old
    // moods on top of the current mascot.
    return RepaintBoundary(
      child: _PetAvatarImage(
        key: ValueKey(mascot.assetPath(mood)),
        mascot: mascot,
        mood: mood,
        phase: phase,
      ),
    );
  }
}

class _PetAvatarImage extends StatelessWidget {
  const _PetAvatarImage({
    super.key,
    required this.mascot,
    required this.mood,
    required this.phase,
  });

  final _PetfyMascot mascot;
  final _PugMood mood;
  final double phase;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      mascot.assetPath(mood),
      cacheWidth: 384,
      fit: BoxFit.contain,
      gaplessPlayback: true,
      filterQuality: FilterQuality.medium,
      frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
        if (wasSynchronouslyLoaded || frame != null) {
          return child;
        }
        return CustomPaint(
          painter: _PetAvatarPainter(mood: mood, phase: phase),
        );
      },
      errorBuilder: (context, error, stackTrace) {
        return CustomPaint(
          painter: _PetAvatarPainter(mood: mood, phase: phase),
        );
      },
    );
  }
}

class _PetAvatarPainter extends CustomPainter {
  _PetAvatarPainter({required this.mood, required this.phase});

  final _PugMood mood;
  final double phase;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final paint = Paint()..isAntiAlias = true;
    final bob = math.sin(phase * math.pi * 2) * _bobAmount;
    final blink = math.sin(phase * math.pi * 2);
    final eyeHeight = blink > 0.94 ? size.height * 0.025 : size.height * 0.095;
    final faceCenter = center.translate(0, size.height * 0.04 + bob);
    final accent = switch (mood) {
      _PugMood.idle => const Color(0xFF64748B),
      _PugMood.working => const Color(0xFF2563EB),
      _PugMood.completed => const Color(0xFF16A34A),
      _PugMood.attention => const Color(0xFFD97706),
    };

    paint
      ..style = PaintingStyle.fill
      ..color = accent.withValues(alpha: 0.10);
    canvas.drawCircle(center, size.width * 0.48, paint);

    if (mood == _PugMood.working || mood == _PugMood.attention) {
      paint
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.width * 0.045
        ..strokeCap = StrokeCap.round
        ..color = accent.withValues(alpha: 0.55);
      final start = phase * math.pi * 2;
      final sweep = mood == _PugMood.attention
          ? math.pi * 1.65
          : math.pi * 1.15;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: size.width * 0.47),
        start,
        sweep,
        false,
        paint,
      );
    }

    paint
      ..style = PaintingStyle.fill
      ..color = const Color(0xFF5B3A2B);
    canvas.drawOval(
      Rect.fromCenter(
        center: faceCenter.translate(-size.width * 0.24, -size.height * 0.12),
        width: size.width * 0.24,
        height: size.height * 0.32,
      ),
      paint,
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: faceCenter.translate(size.width * 0.24, -size.height * 0.12),
        width: size.width * 0.24,
        height: size.height * 0.32,
      ),
      paint,
    );

    paint.color = const Color(0xFFF2D7B2);
    canvas.drawOval(
      Rect.fromCenter(
        center: faceCenter,
        width: size.width * 0.68,
        height: size.height * 0.72,
      ),
      paint,
    );

    paint.color = const Color(0xFF7A4E36);
    canvas.drawOval(
      Rect.fromCenter(
        center: faceCenter.translate(0, size.height * 0.09),
        width: size.width * 0.46,
        height: size.height * 0.38,
      ),
      paint,
    );

    paint.color = const Color(0xFFFFEED8);
    canvas.drawOval(
      Rect.fromCenter(
        center: faceCenter.translate(0, size.height * 0.17),
        width: size.width * 0.43,
        height: size.height * 0.24,
      ),
      paint,
    );

    _drawEyes(canvas, paint, faceCenter, size, eyeHeight);
    _drawNoseAndMouth(canvas, paint, faceCenter, size);

    if (mood == _PugMood.completed) {
      _drawCompletedSpark(canvas, paint, center, size);
    } else if (mood == _PugMood.attention) {
      _drawAttentionMark(canvas, paint, center, size);
    } else if (mood == _PugMood.working) {
      _drawWorkingDots(canvas, paint, faceCenter, size);
    }
  }

  double get _bobAmount {
    return switch (mood) {
      _PugMood.idle => 1.1,
      _PugMood.working => 2.6,
      _PugMood.completed => 1.8,
      _PugMood.attention => 2.2,
    };
  }

  void _drawEyes(
    Canvas canvas,
    Paint paint,
    Offset faceCenter,
    Size size,
    double eyeHeight,
  ) {
    paint
      ..style = PaintingStyle.fill
      ..color = const Color(0xFF111827);
    canvas.drawOval(
      Rect.fromCenter(
        center: faceCenter.translate(-size.width * 0.13, -size.height * 0.06),
        width: size.width * 0.09,
        height: eyeHeight,
      ),
      paint,
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: faceCenter.translate(size.width * 0.13, -size.height * 0.06),
        width: size.width * 0.09,
        height: eyeHeight,
      ),
      paint,
    );

    if (eyeHeight > size.height * 0.04) {
      paint.color = Colors.white.withValues(alpha: 0.9);
      canvas.drawCircle(
        faceCenter.translate(-size.width * 0.145, -size.height * 0.075),
        size.width * 0.017,
        paint,
      );
      canvas.drawCircle(
        faceCenter.translate(size.width * 0.115, -size.height * 0.075),
        size.width * 0.017,
        paint,
      );
    }
  }

  void _drawNoseAndMouth(
    Canvas canvas,
    Paint paint,
    Offset faceCenter,
    Size size,
  ) {
    paint
      ..style = PaintingStyle.fill
      ..color = const Color(0xFF111827);
    canvas.drawOval(
      Rect.fromCenter(
        center: faceCenter.translate(0, size.height * 0.08),
        width: size.width * 0.12,
        height: size.height * 0.075,
      ),
      paint,
    );

    paint
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.032
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFF111827);
    canvas.drawArc(
      Rect.fromCenter(
        center: faceCenter.translate(-size.width * 0.055, size.height * 0.16),
        width: size.width * 0.12,
        height: size.height * 0.09,
      ),
      0.0,
      math.pi * 0.85,
      false,
      paint,
    );
    canvas.drawArc(
      Rect.fromCenter(
        center: faceCenter.translate(size.width * 0.055, size.height * 0.16),
        width: size.width * 0.12,
        height: size.height * 0.09,
      ),
      math.pi * 0.15,
      math.pi * 0.85,
      false,
      paint,
    );
  }

  void _drawCompletedSpark(
    Canvas canvas,
    Paint paint,
    Offset center,
    Size size,
  ) {
    paint
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.038
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFF16A34A);
    final path = Path()
      ..moveTo(center.dx - size.width * 0.20, center.dy - size.height * 0.29)
      ..lineTo(center.dx - size.width * 0.09, center.dy - size.height * 0.18)
      ..lineTo(center.dx + size.width * 0.18, center.dy - size.height * 0.34);
    canvas.drawPath(path, paint);
  }

  void _drawAttentionMark(
    Canvas canvas,
    Paint paint,
    Offset center,
    Size size,
  ) {
    paint
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.040
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFFD97706);
    final x = center.dx + size.width * 0.23;
    canvas.drawLine(
      Offset(x, center.dy - size.height * 0.34),
      Offset(x, center.dy - size.height * 0.22),
      paint,
    );
    paint.style = PaintingStyle.fill;
    canvas.drawCircle(
      Offset(x, center.dy - size.height * 0.15),
      size.width * 0.026,
      paint,
    );
  }

  void _drawWorkingDots(
    Canvas canvas,
    Paint paint,
    Offset faceCenter,
    Size size,
  ) {
    paint
      ..style = PaintingStyle.fill
      ..color = const Color(0xFF2563EB);
    for (var index = 0; index < 3; index += 1) {
      final offsetPhase = (phase + index / 3) % 1;
      final radius =
          size.width * (0.018 + math.sin(offsetPhase * math.pi).abs() * 0.010);
      canvas.drawCircle(
        faceCenter.translate(
          (index - 1) * size.width * 0.09,
          size.height * 0.34,
        ),
        radius,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _PetAvatarPainter oldDelegate) {
    return oldDelegate.mood != mood || oldDelegate.phase != phase;
  }
}

class _TaskPopover extends StatelessWidget {
  const _TaskPopover({
    required this.activeTasks,
    required this.notificationTasks,
    required this.error,
    required this.latestEventPath,
    required this.focusingKey,
    required this.view,
    required this.diagnostics,
    required this.repairingSetup,
    required this.soundsEnabled,
    required this.completedSoundEnabled,
    required this.attentionSoundEnabled,
    required this.autoClearCompleted,
    required this.autoClearCompletedAfterMinutes,
    required this.showEventLog,
    required this.showDebugLog,
    required this.showPetBubble,
    required this.animationsEnabled,
    required this.mascot,
    required this.petSize,
    required this.startupPosition,
    required this.darkPanel,
    required this.launchAtLoginEnabled,
    required this.checkingForUpdates,
    required this.updateFeedUrl,
    required this.updateStatus,
    required this.eventLog,
    required this.debugLog,
    required this.onFocusProject,
    required this.onDismiss,
    required this.onRefresh,
    required this.onRefreshDiagnostics,
    required this.onClear,
    required this.maxHeight,
    required this.onViewChanged,
    required this.onSoundsChanged,
    required this.onCompletedSoundChanged,
    required this.onAttentionSoundChanged,
    required this.onAutoClearCompletedChanged,
    required this.onAutoClearCompletedAfterMinutesChanged,
    required this.onShowEventLogChanged,
    required this.onShowDebugLogChanged,
    required this.onShowPetBubbleChanged,
    required this.onAnimationsEnabledChanged,
    required this.onMascotChanged,
    required this.onPetSizeChanged,
    required this.onStartupPositionChanged,
    required this.onDarkPanelChanged,
    required this.onLaunchAtLoginChanged,
    required this.onCheckForUpdates,
    required this.onOpenUpdate,
    required this.onResetPetPosition,
    required this.onRepairSetup,
    required this.onOpenDiagnostics,
    required this.onDismissSetupGuide,
    required this.onQuit,
  });

  final List<CodexPetEvent> activeTasks;
  final List<CodexPetEvent> notificationTasks;
  final String? error;
  final String latestEventPath;
  final String? focusingKey;
  final _PanelView view;
  final List<SetupDiagnostic> diagnostics;
  final bool repairingSetup;
  final bool soundsEnabled;
  final bool completedSoundEnabled;
  final bool attentionSoundEnabled;
  final bool autoClearCompleted;
  final int autoClearCompletedAfterMinutes;
  final bool showEventLog;
  final bool showDebugLog;
  final bool showPetBubble;
  final bool animationsEnabled;
  final _PetfyMascot mascot;
  final int petSize;
  final String startupPosition;
  final bool darkPanel;
  final bool launchAtLoginEnabled;
  final bool checkingForUpdates;
  final String updateFeedUrl;
  final UpdateCheckResult? updateStatus;
  final List<EventLogEntry> eventLog;
  final List<DebugLogEntry> debugLog;
  final ValueChanged<CodexPetEvent> onFocusProject;
  final ValueChanged<CodexPetEvent> onDismiss;
  final VoidCallback onRefresh;
  final VoidCallback onRefreshDiagnostics;
  final VoidCallback onClear;
  final double maxHeight;
  final ValueChanged<_PanelView> onViewChanged;
  final ValueChanged<bool> onSoundsChanged;
  final ValueChanged<bool> onCompletedSoundChanged;
  final ValueChanged<bool> onAttentionSoundChanged;
  final ValueChanged<bool> onAutoClearCompletedChanged;
  final ValueChanged<int> onAutoClearCompletedAfterMinutesChanged;
  final ValueChanged<bool> onShowEventLogChanged;
  final ValueChanged<bool> onShowDebugLogChanged;
  final ValueChanged<bool> onShowPetBubbleChanged;
  final ValueChanged<bool> onAnimationsEnabledChanged;
  final ValueChanged<_PetfyMascot> onMascotChanged;
  final ValueChanged<int> onPetSizeChanged;
  final ValueChanged<String> onStartupPositionChanged;
  final ValueChanged<bool> onDarkPanelChanged;
  final ValueChanged<bool> onLaunchAtLoginChanged;
  final VoidCallback onCheckForUpdates;
  final VoidCallback onOpenUpdate;
  final VoidCallback onResetPetPosition;
  final VoidCallback onRepairSetup;
  final VoidCallback onOpenDiagnostics;
  final VoidCallback onDismissSetupGuide;
  final VoidCallback onQuit;

  @override
  Widget build(BuildContext context) {
    final isSubScreen =
        view == _PanelView.diagnostics ||
        view == _PanelView.settings ||
        view == _PanelView.eventLog ||
        view == _PanelView.debugLog ||
        view == _PanelView.setup;
    final visibleTasks = view == _PanelView.activity
        ? activeTasks
        : notificationTasks;
    final colors = PetfyPanelColors.fromDarkMode(darkPanel);
    final colorScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF0F766E),
      brightness: darkPanel ? Brightness.dark : Brightness.light,
    );

    return Theme(
      data: Theme.of(context).copyWith(
        brightness: darkPanel ? Brightness.dark : Brightness.light,
        colorScheme: colorScheme,
        iconTheme: IconThemeData(color: colors.icon),
        dividerColor: colors.border,
        popupMenuTheme: PopupMenuThemeData(
          color: colors.menuBackground,
          iconColor: colors.icon,
          textStyle: TextStyle(color: colors.text),
          labelTextStyle: WidgetStatePropertyAll(
            TextStyle(color: colors.text, fontWeight: FontWeight.w700),
          ),
        ),
        textTheme: Theme.of(
          context,
        ).textTheme.apply(bodyColor: colors.text, displayColor: colors.text),
      ),
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: 340,
          constraints: BoxConstraints(maxHeight: maxHeight),
          decoration: BoxDecoration(
            color: colors.background,
            border: Border.all(color: colors.border),
            borderRadius: BorderRadius.circular(8),
            boxShadow: const [
              BoxShadow(
                color: Color(0x22000000),
                blurRadius: 18,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 8, 8),
                child: Row(
                  children: [
                    if (isSubScreen)
                      IconButton(
                        tooltip: 'Back to tasks',
                        onPressed: () => onViewChanged(_PanelView.activity),
                        icon: const Icon(Icons.arrow_back, size: 20),
                      ),
                    Expanded(
                      child: Text(
                        _title,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              color: colors.text,
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                    ),
                    if (view == _PanelView.diagnostics) ...[
                      IconButton(
                        tooltip: 'Refresh diagnostics',
                        onPressed: onRefreshDiagnostics,
                        icon: const Icon(Icons.refresh, size: 20),
                      ),
                      IconButton(
                        tooltip: 'Back to tasks',
                        onPressed: () => onViewChanged(_PanelView.activity),
                        icon: const Icon(Icons.close, size: 20),
                      ),
                    ] else if (view == _PanelView.settings) ...[
                      IconButton(
                        tooltip: 'Back to tasks',
                        onPressed: () => onViewChanged(_PanelView.activity),
                        icon: const Icon(Icons.close, size: 20),
                      ),
                    ] else if (view == _PanelView.eventLog) ...[
                      IconButton(
                        tooltip: 'Refresh event log',
                        onPressed: () => onViewChanged(_PanelView.eventLog),
                        icon: const Icon(Icons.refresh, size: 20),
                      ),
                      IconButton(
                        tooltip: 'Back to tasks',
                        onPressed: () => onViewChanged(_PanelView.activity),
                        icon: const Icon(Icons.close, size: 20),
                      ),
                    ] else if (view == _PanelView.debugLog) ...[
                      IconButton(
                        tooltip: 'Refresh debug log',
                        onPressed: () => onViewChanged(_PanelView.debugLog),
                        icon: const Icon(Icons.refresh, size: 20),
                      ),
                      IconButton(
                        tooltip: 'Back to tasks',
                        onPressed: () => onViewChanged(_PanelView.activity),
                        icon: const Icon(Icons.close, size: 20),
                      ),
                    ] else if (view == _PanelView.setup) ...[
                      IconButton(
                        tooltip: 'Dismiss setup guide',
                        onPressed: onDismissSetupGuide,
                        icon: const Icon(Icons.close, size: 20),
                      ),
                    ] else ...[
                      IconButton(
                        tooltip: 'Clear notifications',
                        onPressed: notificationTasks.isEmpty ? null : onClear,
                        icon: const Icon(Icons.clear_all, size: 20),
                      ),
                      IconButton(
                        tooltip: 'Refresh',
                        onPressed: onRefresh,
                        icon: const Icon(Icons.refresh, size: 20),
                      ),
                      PopupMenuButton<_SettingsAction>(
                        tooltip: 'Settings',
                        icon: const Icon(Icons.settings, size: 20),
                        onSelected: (action) {
                          switch (action) {
                            case _SettingsAction.diagnostics:
                              onViewChanged(_PanelView.diagnostics);
                            case _SettingsAction.eventLog:
                              onViewChanged(_PanelView.eventLog);
                            case _SettingsAction.debugLog:
                              onViewChanged(_PanelView.debugLog);
                            case _SettingsAction.settings:
                              onViewChanged(_PanelView.settings);
                            case _SettingsAction.quit:
                              onQuit();
                          }
                        },
                        itemBuilder: (context) => [
                          const PopupMenuItem(
                            value: _SettingsAction.diagnostics,
                            child: Row(
                              children: [
                                Icon(Icons.health_and_safety, size: 18),
                                SizedBox(width: 10),
                                Text('Diagnostics'),
                              ],
                            ),
                          ),
                          if (showEventLog)
                            const PopupMenuItem(
                              value: _SettingsAction.eventLog,
                              child: Row(
                                children: [
                                  Icon(Icons.receipt_long, size: 18),
                                  SizedBox(width: 10),
                                  Text('Event Log'),
                                ],
                              ),
                            ),
                          if (showDebugLog)
                            const PopupMenuItem(
                              value: _SettingsAction.debugLog,
                              child: Row(
                                children: [
                                  Icon(Icons.bug_report, size: 18),
                                  SizedBox(width: 10),
                                  Text('Debug Log'),
                                ],
                              ),
                            ),
                          const PopupMenuItem(
                            value: _SettingsAction.settings,
                            child: Row(
                              children: [
                                Icon(Icons.tune, size: 18),
                                SizedBox(width: 10),
                                Text('Settings'),
                              ],
                            ),
                          ),
                          const PopupMenuItem(
                            value: _SettingsAction.quit,
                            child: Row(
                              children: [
                                Icon(Icons.close, size: 18),
                                SizedBox(width: 10),
                                Text('Quit Petfy'),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              Divider(height: 1, color: colors.border),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  padding: EdgeInsets.zero,
                  children: [
                    if (view == _PanelView.diagnostics) ...[
                      _DiagnosticsPanel(
                        colors: colors,
                        diagnostics: diagnostics,
                        repairing: repairingSetup,
                        onRepair: onRepairSetup,
                      ),
                    ] else if (view == _PanelView.setup) ...[
                      _SetupGuidePanel(
                        colors: colors,
                        diagnostics: diagnostics,
                        repairing: repairingSetup,
                        onRepair: onRepairSetup,
                        onOpenDiagnostics: onOpenDiagnostics,
                        onDismiss: onDismissSetupGuide,
                      ),
                    ] else if (view == _PanelView.eventLog) ...[
                      _EventLogPanel(
                        colors: colors,
                        entries: eventLog,
                        historyPath: ProjectPaths.historyFile,
                      ),
                    ] else if (view == _PanelView.debugLog) ...[
                      _DebugLogPanel(
                        colors: colors,
                        entries: debugLog,
                        statePath: ProjectPaths.stateDir,
                      ),
                    ] else if (view == _PanelView.settings) ...[
                      _SettingsPanel(
                        colors: colors,
                        soundsEnabled: soundsEnabled,
                        completedSoundEnabled: completedSoundEnabled,
                        attentionSoundEnabled: attentionSoundEnabled,
                        autoClearCompleted: autoClearCompleted,
                        autoClearCompletedAfterMinutes:
                            autoClearCompletedAfterMinutes,
                        showEventLog: showEventLog,
                        showDebugLog: showDebugLog,
                        showPetBubble: showPetBubble,
                        animationsEnabled: animationsEnabled,
                        mascot: mascot,
                        petSize: petSize,
                        startupPosition: startupPosition,
                        darkPanel: darkPanel,
                        launchAtLoginEnabled: launchAtLoginEnabled,
                        checkingForUpdates: checkingForUpdates,
                        updateFeedUrl: updateFeedUrl,
                        updateStatus: updateStatus,
                        onSoundsChanged: onSoundsChanged,
                        onCompletedSoundChanged: onCompletedSoundChanged,
                        onAttentionSoundChanged: onAttentionSoundChanged,
                        onAutoClearCompletedChanged:
                            onAutoClearCompletedChanged,
                        onAutoClearCompletedAfterMinutesChanged:
                            onAutoClearCompletedAfterMinutesChanged,
                        onShowEventLogChanged: onShowEventLogChanged,
                        onShowDebugLogChanged: onShowDebugLogChanged,
                        onShowPetBubbleChanged: onShowPetBubbleChanged,
                        onAnimationsEnabledChanged: onAnimationsEnabledChanged,
                        onMascotChanged: onMascotChanged,
                        onPetSizeChanged: onPetSizeChanged,
                        onStartupPositionChanged: onStartupPositionChanged,
                        onDarkPanelChanged: onDarkPanelChanged,
                        onLaunchAtLoginChanged: onLaunchAtLoginChanged,
                        onCheckForUpdates: onCheckForUpdates,
                        onOpenUpdate: onOpenUpdate,
                        onResetPetPosition: onResetPetPosition,
                        onQuit: onQuit,
                      ),
                    ] else ...[
                      _HomeTabs(
                        colors: colors,
                        view: view,
                        activeCount: activeTasks.length,
                        notificationCount: notificationTasks.length,
                        onViewChanged: onViewChanged,
                      ),
                      if (visibleTasks.isEmpty)
                        _EmptyState(
                          colors: colors,
                          mode: view,
                          latestEventPath: latestEventPath,
                          error: error,
                        )
                      else
                        ..._taskRows(visibleTasks, colors),
                      if (error != null && visibleTasks.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
                          child: Text(
                            error!,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: colors.danger),
                          ),
                        ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String get _title {
    return switch (view) {
      _PanelView.activity => 'Activity',
      _PanelView.notifications => 'Notifications',
      _PanelView.diagnostics => 'Diagnostics',
      _PanelView.settings => 'Settings',
      _PanelView.eventLog => 'Event Log',
      _PanelView.debugLog => 'Debug Log',
      _PanelView.setup => 'Setup',
    };
  }

  List<Widget> _taskRows(List<CodexPetEvent> tasks, PetfyPanelColors colors) {
    final rows = <Widget>[const SizedBox(height: 6)];
    for (var index = 0; index < tasks.length; index += 1) {
      final task = tasks[index];
      rows.add(
        _TaskTile(
          colors: colors,
          task: task,
          focusing: focusingKey == task.taskKey,
          onFocusProject: () => onFocusProject(task),
          onDismiss: () => onDismiss(task),
        ),
      );
      if (index < tasks.length - 1) {
        rows.add(Divider(height: 1, color: colors.border));
      }
    }
    rows.add(const SizedBox(height: 6));
    return rows;
  }
}

enum _PanelView {
  activity,
  notifications,
  diagnostics,
  settings,
  eventLog,
  debugLog,
  setup,
}

enum _SettingsAction { diagnostics, eventLog, debugLog, settings, quit }

class _HomeTabs extends StatelessWidget {
  const _HomeTabs({
    required this.colors,
    required this.view,
    required this.activeCount,
    required this.notificationCount,
    required this.onViewChanged,
  });

  final PetfyPanelColors colors;
  final _PanelView view;
  final int activeCount;
  final int notificationCount;
  final ValueChanged<_PanelView> onViewChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
      child: SegmentedButton<_PanelView>(
        showSelectedIcon: false,
        style: ButtonStyle(
          visualDensity: VisualDensity.compact,
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return colors.isDark
                  ? const Color(0xFF134E4A)
                  : const Color(0xFFCCFBF1);
            }
            return colors.surface;
          }),
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return colors.isDark
                  ? const Color(0xFFCCFBF1)
                  : const Color(0xFF134E4A);
            }
            return colors.text;
          }),
          side: WidgetStatePropertyAll(BorderSide(color: colors.border)),
          textStyle: WidgetStateProperty.all(
            const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
          ),
        ),
        segments: [
          ButtonSegment(
            value: _PanelView.activity,
            icon: const Icon(Icons.bolt, size: 15),
            label: Text('Activity ${_countLabel(activeCount)}'),
          ),
          ButtonSegment(
            value: _PanelView.notifications,
            icon: const Icon(Icons.inbox, size: 15),
            label: Text('Done ${_countLabel(notificationCount)}'),
          ),
        ],
        selected: {view},
        onSelectionChanged: (selected) => onViewChanged(selected.first),
      ),
    );
  }

  String _countLabel(int count) => count > 0 ? '($count)' : '';
}

class _EventLogPanel extends StatelessWidget {
  const _EventLogPanel({
    required this.colors,
    required this.entries,
    required this.historyPath,
  });

  final PetfyPanelColors colors;
  final List<EventLogEntry> entries;
  final String historyPath;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(18, 24, 18, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.receipt_long, size: 30, color: colors.icon),
            const SizedBox(height: 10),
            Text(
              'No raw events yet',
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(
              historyPath,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11, color: colors.pathText),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
            child: Row(
              children: [
                Icon(Icons.folder_open, size: 14, color: colors.icon),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    historyPath,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11, color: colors.pathText),
                  ),
                ),
              ],
            ),
          ),
          ...entries.map(
            (entry) => _EventLogTile(colors: colors, entry: entry),
          ),
        ],
      ),
    );
  }
}

class _EventLogTile extends StatelessWidget {
  const _EventLogTile({required this.colors, required this.entry});

  final PetfyPanelColors colors;
  final EventLogEntry entry;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border.all(color: colors.border),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: entry.statusColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  entry.type,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              Text(
                entry.timeLabel,
                style: TextStyle(fontSize: 11, color: colors.subtleText),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              _SourceBadge(
                colors: colors,
                label: entry.sourceLabel,
                color: entry.sourceColor,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  entry.projectName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: colors.text),
                ),
              ),
            ],
          ),
          if (entry.cwd.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              entry.cwd,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11, color: colors.pathText),
            ),
          ],
          const SizedBox(height: 8),
          SelectableText(
            entry.compactRaw,
            maxLines: 4,
            style: TextStyle(
              fontSize: 10,
              color: colors.subtleText,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }
}

class _SetupGuidePanel extends StatelessWidget {
  const _SetupGuidePanel({
    required this.colors,
    required this.diagnostics,
    required this.repairing,
    required this.onRepair,
    required this.onOpenDiagnostics,
    required this.onDismiss,
  });

  final PetfyPanelColors colors;
  final List<SetupDiagnostic> diagnostics;
  final bool repairing;
  final VoidCallback onRepair;
  final VoidCallback onOpenDiagnostics;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final hasDiagnostics = diagnostics.isNotEmpty;
    final missing = diagnostics.where((diagnostic) => !diagnostic.ok).toList();
    final allOk = hasDiagnostics && missing.isEmpty;
    final checkedCount = diagnostics
        .where((diagnostic) => diagnostic.ok)
        .length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: colors.infoBackground,
                  border: Border.all(color: colors.infoBorder),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  allOk ? Icons.verified : Icons.auto_fix_high,
                  size: 20,
                  color: allOk ? const Color(0xFF16A34A) : colors.infoIcon,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  allOk ? 'Petfy is ready' : 'Finish Petfy setup',
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            allOk
                ? 'Codex events, startup integration, and local state are configured for this user.'
                : 'Petfy needs a small local bridge so it can receive Codex events and open automatically when you sign in.',
            style: TextStyle(color: colors.subtleText, fontSize: 12),
          ),
          const SizedBox(height: 12),
          _SetupStatusCard(
            colors: colors,
            allOk: allOk,
            checkedCount: checkedCount,
            totalCount: diagnostics.length,
            missingCount: missing.length,
          ),
          const SizedBox(height: 10),
          _SetupCapabilityRow(
            colors: colors,
            icon: Icons.notifications_active,
            title: 'Task notifications',
            subtitle: 'Completed and attention events from Codex.',
          ),
          _SetupCapabilityRow(
            colors: colors,
            icon: Icons.terminal,
            title: 'Codex surfaces',
            subtitle: 'Desktop, CLI, and VS Code extension paths.',
          ),
          _SetupCapabilityRow(
            colors: colors,
            icon: Icons.login,
            title: 'Startup',
            subtitle: 'Launches Petfy automatically after sign in.',
          ),
          if (missing.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Needs attention: ${missing.take(3).map((item) => item.label).join(', ')}${missing.length > 3 ? '...' : ''}',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: colors.subtleText,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: allOk || repairing ? null : onRepair,
              icon: repairing
                  ? const SizedBox.square(
                      dimension: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.build, size: 18),
              label: Text(
                repairing
                    ? 'Setting up...'
                    : allOk
                    ? 'Setup complete'
                    : 'Setup Petfy',
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onOpenDiagnostics,
                  icon: const Icon(Icons.health_and_safety, size: 17),
                  label: const Text('Diagnostics'),
                ),
              ),
              const SizedBox(width: 8),
              TextButton(onPressed: onDismiss, child: const Text('Skip')),
            ],
          ),
        ],
      ),
    );
  }
}

class _SetupStatusCard extends StatelessWidget {
  const _SetupStatusCard({
    required this.colors,
    required this.allOk,
    required this.checkedCount,
    required this.totalCount,
    required this.missingCount,
  });

  final PetfyPanelColors colors;
  final bool allOk;
  final int checkedCount;
  final int totalCount;
  final int missingCount;

  @override
  Widget build(BuildContext context) {
    final statusColor = allOk
        ? const Color(0xFF16A34A)
        : const Color(0xFFD97706);
    final title = allOk
        ? 'Everything is connected'
        : totalCount == 0
        ? 'Checking setup'
        : '$missingCount item${missingCount == 1 ? '' : 's'} need attention';
    final subtitle = totalCount == 0
        ? 'Open diagnostics or run setup to verify local integration.'
        : '$checkedCount of $totalCount checks are passing.';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border.all(color: colors.border),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Row(
        children: [
          Icon(
            allOk ? Icons.check_circle : Icons.warning_amber_rounded,
            size: 20,
            color: statusColor,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: colors.text,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: colors.subtleText, fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SetupCapabilityRow extends StatelessWidget {
  const _SetupCapabilityRow({
    required this.colors,
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final PetfyPanelColors colors;
  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        children: [
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: colors.surfaceMuted,
              border: Border.all(color: colors.border),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(icon, size: 15, color: colors.icon),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: colors.text,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: colors.subtleText, fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DiagnosticsPanel extends StatelessWidget {
  const _DiagnosticsPanel({
    required this.colors,
    required this.diagnostics,
    required this.repairing,
    required this.onRepair,
  });

  final PetfyPanelColors colors;
  final List<SetupDiagnostic> diagnostics;
  final bool repairing;
  final VoidCallback onRepair;

  @override
  Widget build(BuildContext context) {
    final allOk =
        diagnostics.isNotEmpty &&
        diagnostics.every((diagnostic) => diagnostic.ok);

    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(bottom: BorderSide(color: colors.border)),
      ),
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(
                allOk ? Icons.check_circle : Icons.error,
                size: 18,
                color: allOk
                    ? const Color(0xFF16A34A)
                    : const Color(0xFFD97706),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  allOk ? 'Setup healthy' : 'Setup needs attention',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              IconButton(
                tooltip: 'Repair setup',
                onPressed: repairing ? null : onRepair,
                icon: repairing
                    ? const SizedBox.square(
                        dimension: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.build, size: 16),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 230),
            child: ListView(
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              children: [
                ...diagnostics.map(
                  (diagnostic) =>
                      _DiagnosticRow(colors: colors, diagnostic: diagnostic),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DebugLogPanel extends StatelessWidget {
  const _DebugLogPanel({
    required this.colors,
    required this.entries,
    required this.statePath,
  });

  final PetfyPanelColors colors;
  final List<DebugLogEntry> entries;
  final String statePath;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(18, 24, 18, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.bug_report, size: 30, color: colors.icon),
            const SizedBox(height: 10),
            Text(
              'No debug logs yet',
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(
              statePath,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11, color: colors.pathText),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
            child: Row(
              children: [
                Icon(Icons.folder_open, size: 14, color: colors.icon),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    statePath,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11, color: colors.pathText),
                  ),
                ),
              ],
            ),
          ),
          ...entries.map(
            (entry) => _DebugLogTile(colors: colors, entry: entry),
          ),
        ],
      ),
    );
  }
}

class _DebugLogTile extends StatelessWidget {
  const _DebugLogTile({required this.colors, required this.entry});

  final PetfyPanelColors colors;
  final DebugLogEntry entry;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border.all(color: colors.border),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.description, size: 14, color: colors.icon),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  entry.source,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colors.text,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            entry.message,
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: colors.subtleText,
              fontSize: 11,
              height: 1.25,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsPanel extends StatelessWidget {
  const _SettingsPanel({
    required this.colors,
    required this.soundsEnabled,
    required this.completedSoundEnabled,
    required this.attentionSoundEnabled,
    required this.autoClearCompleted,
    required this.autoClearCompletedAfterMinutes,
    required this.showEventLog,
    required this.showDebugLog,
    required this.showPetBubble,
    required this.animationsEnabled,
    required this.mascot,
    required this.petSize,
    required this.startupPosition,
    required this.darkPanel,
    required this.launchAtLoginEnabled,
    required this.checkingForUpdates,
    required this.updateFeedUrl,
    required this.updateStatus,
    required this.onSoundsChanged,
    required this.onCompletedSoundChanged,
    required this.onAttentionSoundChanged,
    required this.onAutoClearCompletedChanged,
    required this.onAutoClearCompletedAfterMinutesChanged,
    required this.onShowEventLogChanged,
    required this.onShowDebugLogChanged,
    required this.onShowPetBubbleChanged,
    required this.onAnimationsEnabledChanged,
    required this.onMascotChanged,
    required this.onPetSizeChanged,
    required this.onStartupPositionChanged,
    required this.onDarkPanelChanged,
    required this.onLaunchAtLoginChanged,
    required this.onCheckForUpdates,
    required this.onOpenUpdate,
    required this.onResetPetPosition,
    required this.onQuit,
  });

  final PetfyPanelColors colors;
  final bool soundsEnabled;
  final bool completedSoundEnabled;
  final bool attentionSoundEnabled;
  final bool autoClearCompleted;
  final int autoClearCompletedAfterMinutes;
  final bool showEventLog;
  final bool showDebugLog;
  final bool showPetBubble;
  final bool animationsEnabled;
  final _PetfyMascot mascot;
  final int petSize;
  final String startupPosition;
  final bool darkPanel;
  final bool launchAtLoginEnabled;
  final bool checkingForUpdates;
  final String updateFeedUrl;
  final UpdateCheckResult? updateStatus;
  final ValueChanged<bool> onSoundsChanged;
  final ValueChanged<bool> onCompletedSoundChanged;
  final ValueChanged<bool> onAttentionSoundChanged;
  final ValueChanged<bool> onAutoClearCompletedChanged;
  final ValueChanged<int> onAutoClearCompletedAfterMinutesChanged;
  final ValueChanged<bool> onShowEventLogChanged;
  final ValueChanged<bool> onShowDebugLogChanged;
  final ValueChanged<bool> onShowPetBubbleChanged;
  final ValueChanged<bool> onAnimationsEnabledChanged;
  final ValueChanged<_PetfyMascot> onMascotChanged;
  final ValueChanged<int> onPetSizeChanged;
  final ValueChanged<String> onStartupPositionChanged;
  final ValueChanged<bool> onDarkPanelChanged;
  final ValueChanged<bool> onLaunchAtLoginChanged;
  final VoidCallback onCheckForUpdates;
  final VoidCallback onOpenUpdate;
  final VoidCallback onResetPetPosition;
  final VoidCallback onQuit;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _SettingsSwitchTile(
            colors: colors,
            icon: Icons.volume_up,
            title: 'Sounds',
            subtitle: soundsEnabled
                ? 'Play sounds for enabled event types.'
                : 'Disable every Petfy sound.',
            value: soundsEnabled,
            onChanged: onSoundsChanged,
          ),
          const SizedBox(height: 8),
          _SettingsSwitchTile(
            colors: colors,
            icon: Icons.check_circle,
            title: 'Completed sound',
            subtitle: 'Play a sound when a Codex task finishes.',
            value: soundsEnabled && completedSoundEnabled,
            onChanged: soundsEnabled ? onCompletedSoundChanged : null,
          ),
          const SizedBox(height: 8),
          _SettingsSwitchTile(
            colors: colors,
            icon: Icons.priority_high,
            title: 'Attention sound',
            subtitle: 'Play a sound when Codex needs approval or input.',
            value: soundsEnabled && attentionSoundEnabled,
            onChanged: soundsEnabled ? onAttentionSoundChanged : null,
          ),
          const SizedBox(height: 8),
          _SettingsSwitchTile(
            colors: colors,
            icon: Icons.animation,
            title: 'Animations',
            subtitle: 'Animate the pet while tasks change state.',
            value: animationsEnabled,
            onChanged: onAnimationsEnabledChanged,
          ),
          const SizedBox(height: 8),
          _SettingsSelectTile(
            colors: colors,
            icon: Icons.face,
            title: 'Mascot',
            value: mascot.id,
            options: _PetfyMascot.options,
            onChanged: (value) =>
                onMascotChanged(_PetfyMascot.fromStored(value)),
          ),
          const SizedBox(height: 8),
          _SettingsSliderTile(
            colors: colors,
            icon: Icons.photo_size_select_large,
            title: 'Pet size',
            value: petSize,
            min: 80,
            max: 136,
            divisions: 14,
            suffix: 'px',
            onChanged: onPetSizeChanged,
          ),
          const SizedBox(height: 8),
          _SettingsSelectTile(
            colors: colors,
            icon: Icons.push_pin,
            title: 'Startup position',
            value: startupPosition,
            options: _SelectOption.startupOptions,
            onChanged: onStartupPositionChanged,
          ),
          const SizedBox(height: 8),
          _SettingsSwitchTile(
            colors: colors,
            icon: Icons.auto_delete,
            title: 'Auto-clear completed',
            subtitle: autoClearCompleted
                ? 'Clear completed notifications after $autoClearCompletedAfterMinutes minutes.'
                : 'Clear old completed notifications automatically.',
            value: autoClearCompleted,
            onChanged: onAutoClearCompletedChanged,
          ),
          if (autoClearCompleted) ...[
            const SizedBox(height: 8),
            _SettingsSliderTile(
              colors: colors,
              icon: Icons.timer,
              title: 'Auto-clear delay',
              value: autoClearCompletedAfterMinutes,
              onChanged: onAutoClearCompletedAfterMinutesChanged,
            ),
          ],
          const SizedBox(height: 8),
          _SettingsSwitchTile(
            colors: colors,
            icon: Icons.pets,
            title: 'Pet bubble',
            subtitle: showPetBubble
                ? 'Show the circular background behind the pet.'
                : 'Show only the pet without the circular background.',
            value: showPetBubble,
            onChanged: onShowPetBubbleChanged,
          ),
          const SizedBox(height: 8),
          _SettingsSwitchTile(
            colors: colors,
            icon: Icons.dark_mode,
            title: 'Dark panel',
            subtitle: 'Use a darker shell for the task panel.',
            value: darkPanel,
            onChanged: onDarkPanelChanged,
          ),
          const SizedBox(height: 8),
          _SettingsSwitchTile(
            colors: colors,
            icon: Icons.login,
            title: 'Launch at login',
            subtitle: 'Start Petfy automatically for this user.',
            value: launchAtLoginEnabled,
            onChanged: onLaunchAtLoginChanged,
          ),
          const SizedBox(height: 8),
          _UpdateSettingsTile(
            colors: colors,
            feedUrl: updateFeedUrl,
            status: updateStatus,
            checking: checkingForUpdates,
            onCheck: onCheckForUpdates,
            onOpen: updateStatus?.canOpen == true ? onOpenUpdate : null,
          ),
          const SizedBox(height: 8),
          _SettingsSwitchTile(
            colors: colors,
            icon: Icons.receipt_long,
            title: 'Event Log',
            subtitle: 'Show raw captured Codex events in the settings menu.',
            value: showEventLog,
            onChanged: onShowEventLogChanged,
          ),
          const SizedBox(height: 8),
          _SettingsSwitchTile(
            colors: colors,
            icon: Icons.bug_report,
            title: 'Debug Log',
            subtitle:
                'Show local hook, notify, and bridge logs when debugging.',
            value: showDebugLog,
            onChanged: onShowDebugLogChanged,
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onResetPetPosition,
              icon: const Icon(Icons.center_focus_strong, size: 18),
              label: const Text('Reset pet position'),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onQuit,
              icon: const Icon(Icons.close, size: 18),
              label: const Text('Quit Petfy'),
            ),
          ),
        ],
      ),
    );
  }
}

class _UpdateSettingsTile extends StatelessWidget {
  const _UpdateSettingsTile({
    required this.colors,
    required this.feedUrl,
    required this.status,
    required this.checking,
    required this.onCheck,
    required this.onOpen,
  });

  final PetfyPanelColors colors;
  final String feedUrl;
  final UpdateCheckResult? status;
  final bool checking;
  final VoidCallback onCheck;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final status = this.status;
    final titleColor = status?.failed == true
        ? const Color(0xFFDC2626)
        : status?.updateAvailable == true
        ? const Color(0xFF0F766E)
        : colors.text;
    final message =
        status?.message ??
        (feedUrl.isEmpty
            ? 'No update feed configured for this build.'
            : 'Check the configured update feed.');

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border.all(color: colors.border),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.system_update_alt, size: 18, color: colors.icon),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Updates',
                      style: TextStyle(
                        color: colors.text,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      message,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: titleColor,
                        fontSize: 12,
                        height: 1.2,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Current: ${PetfyVersion.current}',
                      style: TextStyle(color: colors.subtleText, fontSize: 11),
                    ),
                    if (status != null && status.updateAvailable) ...[
                      const SizedBox(height: 3),
                      Text(
                        status.securityNote,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: colors.subtleText,
                          fontSize: 11,
                          height: 1.2,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: checking || feedUrl.isEmpty ? null : onCheck,
                  icon: checking
                      ? SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: colors.icon,
                          ),
                        )
                      : const Icon(Icons.refresh, size: 18),
                  label: Text(checking ? 'Checking' : 'Check'),
                ),
              ),
              if (onOpen != null) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: onOpen,
                    icon: const Icon(Icons.open_in_new, size: 18),
                    label: Text(status?.openLabel ?? 'Open'),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _SettingsSwitchTile extends StatelessWidget {
  const _SettingsSwitchTile({
    required this.colors,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final PetfyPanelColors colors;
  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border.all(color: colors.border),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            size: 18,
            color: onChanged == null ? colors.subtleText : colors.icon,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: colors.text,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colors.subtleText,
                    fontSize: 12,
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

class _SelectOption {
  const _SelectOption({required this.value, required this.label});

  static const startupOptions = [
    _SelectOption(value: 'remember', label: 'Remember last position'),
    _SelectOption(value: 'topRight', label: 'Top right'),
    _SelectOption(value: 'topLeft', label: 'Top left'),
    _SelectOption(value: 'bottomRight', label: 'Bottom right'),
    _SelectOption(value: 'bottomLeft', label: 'Bottom left'),
  ];

  static bool isValid(String? value) {
    return startupOptions.any((option) => option.value == value);
  }

  final String value;
  final String label;
}

class _SettingsSelectTile extends StatelessWidget {
  const _SettingsSelectTile({
    required this.colors,
    required this.icon,
    required this.title,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final PetfyPanelColors colors;
  final IconData icon;
  final String title;
  final String value;
  final List<_SelectOption> options;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border.all(color: colors.border),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: colors.icon),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              title,
              style: TextStyle(color: colors.text, fontWeight: FontWeight.w800),
            ),
          ),
          DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              dropdownColor: colors.menuBackground,
              iconEnabledColor: colors.icon,
              style: TextStyle(
                color: colors.text,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
              items: options
                  .map(
                    (option) => DropdownMenuItem(
                      value: option.value,
                      child: Text(option.label),
                    ),
                  )
                  .toList(growable: false),
              onChanged: (next) {
                if (next != null) {
                  onChanged(next);
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _DiagnosticRow extends StatelessWidget {
  const _DiagnosticRow({required this.colors, required this.diagnostic});

  final PetfyPanelColors colors;
  final SetupDiagnostic diagnostic;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            diagnostic.ok ? Icons.check : Icons.close,
            size: 16,
            color: diagnostic.ok
                ? const Color(0xFF16A34A)
                : const Color(0xFFDC2626),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  diagnostic.label,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                Text(
                  diagnostic.detail,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: colors.subtleText, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.colors,
    required this.mode,
    required this.latestEventPath,
    required this.error,
  });

  final PetfyPanelColors colors;
  final _PanelView mode;
  final String latestEventPath;
  final String? error;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 18),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: colors.infoBackground,
              shape: BoxShape.circle,
              border: Border.all(color: colors.infoBorder),
            ),
            child: Icon(Icons.auto_awesome, color: colors.infoIcon, size: 26),
          ),
          const SizedBox(height: 12),
          Text(
            mode == _PanelView.activity
                ? 'Nothing running right now'
                : 'No notifications yet',
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
          ),
          const SizedBox(height: 6),
          Text(
            error ??
                (mode == _PanelView.activity
                    ? 'Petfy is watching active Codex sessions.'
                    : 'Completed tasks and attention events will appear here.'),
            textAlign: TextAlign.center,
            style: TextStyle(color: colors.subtleText, height: 1.25),
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: colors.surface,
              border: Border.all(color: colors.border),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              children: [
                Icon(Icons.folder_open, size: 15, color: colors.icon),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    latestEventPath,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11, color: colors.pathText),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsSliderTile extends StatelessWidget {
  const _SettingsSliderTile({
    required this.colors,
    required this.icon,
    required this.title,
    required this.value,
    this.min = 1,
    this.max = 120,
    this.divisions = 119,
    this.suffix = 'min',
    required this.onChanged,
  });

  final PetfyPanelColors colors;
  final IconData icon;
  final String title;
  final int value;
  final int min;
  final int max;
  final int divisions;
  final String suffix;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border.all(color: colors.border),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: colors.icon),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              Text(
                '$value $suffix',
                style: TextStyle(
                  fontSize: 12,
                  color: colors.subtleText,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          Slider(
            value: value.toDouble(),
            min: min.toDouble(),
            max: max.toDouble(),
            divisions: divisions,
            label: '$value $suffix',
            onChanged: (next) => onChanged(next.round()),
          ),
        ],
      ),
    );
  }
}

class _SourceBadge extends StatelessWidget {
  const _SourceBadge({
    required this.colors,
    required this.label,
    required this.color,
  });

  final PetfyPanelColors colors;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final displayColor = colors.isDark && color == const Color(0xFF111827)
        ? const Color(0xFFE5E7EB)
        : color;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: displayColor.withValues(alpha: colors.isDark ? 0.18 : 0.12),
        border: Border.all(color: displayColor.withValues(alpha: 0.35)),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: displayColor,
          fontSize: 10,
          fontWeight: FontWeight.w800,
          height: 1.1,
        ),
      ),
    );
  }
}

class _TaskTile extends StatelessWidget {
  const _TaskTile({
    required this.colors,
    required this.task,
    required this.focusing,
    required this.onFocusProject,
    required this.onDismiss,
  });

  final PetfyPanelColors colors;
  final CodexPetEvent task;
  final bool focusing;
  final VoidCallback onFocusProject;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: ValueKey('task-${task.taskKey}-${task.timestamp}'),
      direction: DismissDirection.horizontal,
      background: _DismissBackground(
        colors: colors,
        alignment: Alignment.centerLeft,
      ),
      secondaryBackground: _DismissBackground(
        colors: colors,
        alignment: Alignment.centerRight,
      ),
      onDismissed: (_) => onDismiss(),
      child: ListTile(
        dense: true,
        leading: Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: task.statusColor,
            shape: BoxShape.circle,
          ),
        ),
        title: Text(
          task.projectName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 3),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _SourceBadge(
                  colors: colors,
                  label: task.sourceLabel,
                  color: task.sourceColor,
                ),
                Text(
                  task.statusLabel,
                  style: TextStyle(
                    fontSize: 12,
                    color: colors.subtleText,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            if (task.message.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                task.message,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: colors.subtleText),
              ),
            ],
          ],
        ),
        trailing: IconButton(
          tooltip: 'Open project',
          onPressed: focusing ? null : onFocusProject,
          icon: focusing
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.open_in_new),
        ),
        onTap: focusing ? null : onFocusProject,
      ),
    );
  }
}

class _DismissBackground extends StatelessWidget {
  const _DismissBackground({required this.colors, required this.alignment});

  final PetfyPanelColors colors;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: alignment,
      padding: const EdgeInsets.symmetric(horizontal: 18),
      color: colors.dismissBackground,
      child: Icon(Icons.check, color: colors.dismissIcon),
    );
  }
}

class CodexPetEvent {
  const CodexPetEvent({
    required this.type,
    required this.cwd,
    required this.projectName,
    required this.message,
    required this.timestamp,
    this.source = 'codex',
    this.threadId,
    this.turnId,
  });

  factory CodexPetEvent.fromJson(Map<String, dynamic> json) {
    return CodexPetEvent(
      type: json['type']?.toString() ?? 'unknown',
      cwd: json['cwd']?.toString() ?? '',
      projectName: json['projectName']?.toString() ?? 'Unknown project',
      message: json['message']?.toString() ?? '',
      timestamp: json['timestamp']?.toString() ?? '',
      source: json['source']?.toString() ?? 'codex',
      threadId: json['threadId']?.toString(),
      turnId: json['turnId']?.toString(),
    );
  }

  final String type;
  final String cwd;
  final String projectName;
  final String message;
  final String timestamp;
  final String source;
  final String? threadId;
  final String? turnId;

  String get taskKey {
    if (turnId != null && turnId!.isNotEmpty) {
      return 'turn:$turnId';
    }
    if (threadId != null && threadId!.isNotEmpty) {
      return 'thread:$threadId';
    }
    return cwd.isNotEmpty ? 'workspace:$cwd' : '$projectName:$timestamp';
  }

  String get soundKey => '$taskKey:$type:$timestamp:$message';

  DateTime get occurredAt =>
      DateTime.tryParse(timestamp)?.toUtc() ??
      DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);

  bool get needsAttention => type == 'task.waiting_approval';

  bool get isActive =>
      type == 'task.started' || type == 'task.waiting_approval';

  bool get isNotification =>
      type == 'task.completed' || type == 'task.waiting_approval';

  bool get isResolutionEvent => type == 'task.completed';

  Color get statusColor {
    return switch (type) {
      'task.completed' => const Color(0xFF16A34A),
      'task.waiting_approval' => const Color(0xFFD97706),
      'task.started' => const Color(0xFF2563EB),
      _ => const Color(0xFF64748B),
    };
  }

  String get statusLabel {
    return switch (type) {
      'task.completed' => 'Completed',
      'task.waiting_approval' => 'Needs approval',
      'task.started' => 'Working',
      _ => type,
    };
  }

  String get sourceLabel => _sourceLabel(source);

  Color get sourceColor => _sourceColor(source);
}

class EventLogEntry {
  EventLogEntry({
    required this.raw,
    required this.type,
    required this.source,
    required this.projectName,
    required this.cwd,
    required this.timestamp,
  });

  factory EventLogEntry.fromRawJson(String raw) {
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      return EventLogEntry(
        raw: raw,
        type: json['type']?.toString() ?? 'unknown',
        source: json['source']?.toString() ?? 'codex',
        projectName: json['projectName']?.toString() ?? 'Unknown project',
        cwd: json['cwd']?.toString() ?? '',
        timestamp: json['timestamp']?.toString() ?? '',
      );
    } on Object {
      return EventLogEntry(
        raw: raw,
        type: 'invalid_json',
        source: 'unknown',
        projectName: 'Unreadable event',
        cwd: '',
        timestamp: '',
      );
    }
  }

  final String raw;
  final String type;
  final String source;
  final String projectName;
  final String cwd;
  final String timestamp;

  String get compactRaw => raw.replaceAll(RegExp(r'\s+'), ' ').trim();

  Color get statusColor {
    return switch (type) {
      'task.completed' => const Color(0xFF16A34A),
      'task.waiting_approval' => const Color(0xFFD97706),
      'task.started' => const Color(0xFF2563EB),
      _ => const Color(0xFF64748B),
    };
  }

  String get sourceLabel => _sourceLabel(source);

  Color get sourceColor => _sourceColor(source);

  String get timeLabel {
    final parsed = DateTime.tryParse(timestamp)?.toLocal();
    if (parsed == null) {
      return '--:--';
    }
    final hour = parsed.hour.toString().padLeft(2, '0');
    final minute = parsed.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}

class DebugLogEntry {
  const DebugLogEntry({
    required this.source,
    required this.path,
    required this.message,
  });

  final String source;
  final String path;
  final String message;
}

String _sourceLabel(String source) {
  return switch (source.toLowerCase()) {
    'desktop' => 'Desktop',
    'vscode' => 'VS Code',
    'cli' => 'CLI',
    'hook' => 'Hook',
    'notify' => 'Notify',
    'codex' => 'Codex',
    _ => source.isEmpty ? 'Unknown' : source,
  };
}

Color _sourceColor(String source) {
  return switch (source.toLowerCase()) {
    'desktop' => const Color(0xFF7C3AED),
    'vscode' => const Color(0xFF2563EB),
    'cli' => const Color(0xFF0F766E),
    'hook' => const Color(0xFFD97706),
    'notify' => const Color(0xFF475569),
    'codex' => const Color(0xFF111827),
    _ => const Color(0xFF64748B),
  };
}

class SetupDiagnostic {
  const SetupDiagnostic({
    required this.label,
    required this.ok,
    required this.detail,
  });

  final String label;
  final bool ok;
  final String detail;
}

class PetfyVersion {
  static const String current = String.fromEnvironment(
    'PETFY_VERSION',
    defaultValue: '0.0.1',
  );
}

class UpdateCheckResult {
  const UpdateCheckResult({
    required this.currentVersion,
    required this.latestVersion,
    required this.updateAvailable,
    required this.message,
    this.releaseNotesUrl,
    this.artifactUrl,
    this.artifactSha256,
    this.artifactName,
    this.error,
  });

  factory UpdateCheckResult.failure({
    required String currentVersion,
    required String message,
  }) {
    return UpdateCheckResult(
      currentVersion: currentVersion,
      latestVersion: currentVersion,
      updateAvailable: false,
      message: message,
      error: message,
    );
  }

  final String currentVersion;
  final String latestVersion;
  final bool updateAvailable;
  final String message;
  final String? releaseNotesUrl;
  final String? artifactUrl;
  final String? artifactSha256;
  final String? artifactName;
  final String? error;

  bool get failed => error != null;

  bool get hasVerifiedArtifact =>
      artifactUrl != null &&
      artifactUrl!.isNotEmpty &&
      artifactSha256 != null &&
      artifactSha256!.isNotEmpty;

  String? get preferredOpenUrl {
    if (hasVerifiedArtifact) {
      return artifactUrl;
    }
    if (releaseNotesUrl != null && releaseNotesUrl!.isNotEmpty) {
      return releaseNotesUrl;
    }
    return artifactUrl;
  }

  String get openLabel => hasVerifiedArtifact ? 'Download' : 'Release';

  String get securityNote {
    if (hasVerifiedArtifact) {
      return 'Artifact checksum is available for verification.';
    }
    if (artifactUrl != null && artifactUrl!.isNotEmpty) {
      return 'No checksum yet; opening release page instead.';
    }
    return 'No artifact for this OS in the update feed yet.';
  }

  bool get canOpen =>
      updateAvailable &&
      preferredOpenUrl != null &&
      preferredOpenUrl!.isNotEmpty;
}

class UpdateArtifact {
  const UpdateArtifact({
    required this.name,
    required this.url,
    required this.sha256,
  });

  final String name;
  final String url;
  final String sha256;
}

class ProjectPaths {
  static const String _definedRoot = String.fromEnvironment('PETFY_ROOT');
  static const String _definedStateDir = String.fromEnvironment(
    'PETFY_STATE_DIR',
  );
  static const String _definedNodePath = String.fromEnvironment(
    'PETFY_NODE_PATH',
  );
  static const String _definedUpdateFeedUrl = String.fromEnvironment(
    'PETFY_UPDATE_FEED_URL',
  );

  static final String repoRoot = _definedRoot.isNotEmpty
      ? _definedRoot
      : Platform.environment['PETFY_ROOT'] ?? _defaultRuntimeRoot;

  static String get stateDir => _definedStateDir.isNotEmpty
      ? _definedStateDir
      : Platform.environment['PETFY_STATE_DIR'] ?? _defaultStateDir;

  static String get _defaultStateDir {
    final home = Platform.environment['HOME'];
    if (home != null && home.isNotEmpty) {
      return '$home/.petfy';
    }
    return '$repoRoot/.state';
  }

  static String get _defaultRuntimeRoot {
    final home = Platform.environment['HOME'];
    if (home != null && home.isNotEmpty) {
      return '$home/Library/Application Support/Petfy';
    }
    return Directory.current.parent.absolute.path;
  }

  static String get latestEventFile => '$stateDir/latest-event.json';

  static String get historyFile => '$stateDir/events.jsonl';

  static String get bridgeLogFile => '$stateDir/bridge.log';

  static String get notifyLogFile => '$stateDir/notify.log';

  static String get settingsFile => '$stateDir/settings.json';

  static String get updateFeedFile => '$repoRoot/dist/update/latest.json';

  static String get defaultUpdateFeedUrl {
    if (_definedUpdateFeedUrl.isNotEmpty) {
      return _definedUpdateFeedUrl;
    }
    if (File(updateFeedFile).existsSync()) {
      return Uri.file(updateFeedFile).toString();
    }
    return 'https://raw.githubusercontent.com/josehenriquefs/petfy/main/dist/update/latest.json';
  }

  static String get bridgeCli => '$repoRoot/bridge/src/cli.js';

  static String get hookScript => '$repoRoot/scripts/petfy-event.sh';

  static String get installCodexScript =>
      '$repoRoot/scripts/install-codex-integration.js';

  static String get codexHooksFile {
    final codexHome = Platform.environment['CODEX_HOME'];
    final home = Platform.environment['HOME'];
    if (codexHome != null && codexHome.isNotEmpty) {
      return '$codexHome/hooks.json';
    }
    return '${home ?? repoRoot}/.codex/hooks.json';
  }

  static String get codexConfigFile {
    final codexHome = Platform.environment['CODEX_HOME'];
    final home = Platform.environment['HOME'];
    if (codexHome != null && codexHome.isNotEmpty) {
      return '$codexHome/config.toml';
    }
    return '${home ?? repoRoot}/.codex/config.toml';
  }

  static String get codexSessionsDir {
    final codexHome = Platform.environment['CODEX_HOME'];
    final home = Platform.environment['HOME'];
    if (codexHome != null && codexHome.isNotEmpty) {
      return '$codexHome/sessions';
    }
    return '${home ?? repoRoot}/.codex/sessions';
  }

  static String get launchAgentFile {
    final home = Platform.environment['HOME'];
    return '${home ?? repoRoot}/Library/LaunchAgents/dev.petfy.pet.plist';
  }

  static const String launchAgentLabel = 'dev.petfy.pet';

  static String get installedAppExecutable {
    final home = Platform.environment['HOME'];
    return '${home ?? repoRoot}/Applications/Petfy.app/Contents/MacOS/Petfy';
  }

  static String get stdoutLog => '$stateDir/petfy.out.log';

  static String get stderrLog => '$stateDir/petfy.err.log';

  static String launchAgentPlist() {
    return '''<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>$launchAgentLabel</string>
  <key>ProgramArguments</key>
  <array>
    <string>${_escapeXml(installedAppExecutable)}</string>
  </array>
  <key>EnvironmentVariables</key>
  <dict>
    <key>PETFY_ROOT</key>
    <string>${_escapeXml(repoRoot)}</string>
    <key>PETFY_STATE_DIR</key>
    <string>${_escapeXml(stateDir)}</string>
  </dict>
  <key>RunAtLoad</key>
  <true/>
  <key>KeepAlive</key>
  <false/>
  <key>StandardOutPath</key>
  <string>${_escapeXml(stdoutLog)}</string>
  <key>StandardErrorPath</key>
  <string>${_escapeXml(stderrLog)}</string>
</dict>
</plist>
''';
  }

  static String _escapeXml(String value) {
    return value
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;');
  }

  static String get nodeBinary {
    if (_definedNodePath.isNotEmpty) {
      return _definedNodePath;
    }
    return Platform.environment['PETFY_NODE_PATH'] ?? 'node';
  }
}

enum PetSound { completed, attention }

class WindowController {
  static const MethodChannel _channel = MethodChannel('petfy/window');

  static void beginDrag() {
    unawaited(_invoke('beginDrag'));
  }

  static void drag() {
    unawaited(_invoke('drag'));
  }

  static Future<void> setExpanded(
    bool expanded, {
    double? height,
    PopoverPlacement? placement,
  }) {
    final arguments = <String, Object?>{'expanded': expanded};
    if (height != null) {
      arguments['height'] = height;
    }
    if (placement != null) {
      arguments['placement'] = placement.nativeValue;
    }
    return _invoke('setExpanded', arguments);
  }

  static Future<PopoverPlacement> popoverPlacement() async {
    try {
      final value = await _channel.invokeMethod<Object?>('popoverPlacement');
      return PopoverPlacement.fromNative(value);
    } on MissingPluginException {
      return PopoverPlacement.leftDown;
    }
  }

  static void playSound(PetSound sound) {
    unawaited(_invoke('playSound', sound.name));
  }

  static void quitApp() {
    unawaited(_invoke('quitApp'));
  }

  static Future<void> resetPosition() {
    return _invoke('resetPosition');
  }

  static Future<void> setStartupPosition(String position, {bool move = false}) {
    return _invoke('setStartupPosition', {'position': position, 'move': move});
  }

  static Future<void> _invoke(String method, [Object? arguments]) async {
    try {
      await _channel.invokeMethod<void>(method, arguments);
    } on MissingPluginException {
      return;
    }
  }
}
