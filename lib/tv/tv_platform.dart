import 'dart:io' show Platform;

import 'package:PiliPlus/utils/storage.dart';
import 'package:PiliPlus/utils/storage_key.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:hive_ce/hive.dart';

class _TvTextInputGateControl with TextInputControl {
  @override
  void show() {
    if (!TvPlatform.isSoftKeyboardAllowed) {
      SystemChannels.textInput.invokeMethod<void>('TextInput.hide').ignore();
      TvPlatform.hideSoftKeyboard().ignore();
    }
  }
}

/// Runtime detection, first-launch Hive preference seeding, and soft-keyboard
/// gating for Android TV / Leanback devices.
abstract final class TvPlatform {
  static const MethodChannel _channel = MethodChannel('com.example.piliplus/tv');
  static const String _seededMarkerKey = 'tvDefaultsSeededV1';

  static const bool _forceTvFromEnv =
      bool.fromEnvironment('PILI_FORCE_TV') ||
      bool.fromEnvironment('PILIPLUS_TV');

  static final _TvTextInputGateControl _gateControl =
      _TvTextInputGateControl();

  static bool _initialized = false;
  static bool _isTv = false;
  static bool _hasTouchscreen = true;
  static bool _gateInstalled = false;
  static FocusNode? _unlockedNode;

  /// Default TV-friendly settings seeded on first TV launch for keys the user
  /// has not explicitly configured yet.
  static const Map<String, Object> defaultTvSettings = <String, Object>{
    SettingBoxKey.horizontalScreen: true,
    SettingBoxKey.useSideBar: true,
    SettingBoxKey.enableVerticalExpand: false,
    SettingBoxKey.enableAutoEnter: true,
    'defaultFullScreen': true,
    SettingBoxKey.enableAutoExit: false,
    SettingBoxKey.autoPlayEnable: true,
    SettingBoxKey.enableShowDanmaku: true,
    SettingBoxKey.fullScreenMode: 1, // FullScreenMode.none.index
    SettingBoxKey.recommendCardWidth: 300.0,
    SettingBoxKey.defaultTextScale: 1.2,
    SettingBoxKey.showFsScreenshotBtn: false,
    SettingBoxKey.showFsLockBtn: false,
    SettingBoxKey.themeMode: 1, // ThemeType.dark.index
  };

  /// Returns `true` when running on an Android TV / Leanback device or when
  /// forced via `--dart-define=PILI_FORCE_TV=true`.
  static bool get isTv => _isTv || _forceTvFromEnv;

  /// Returns `true` when the device reports a physical touchscreen.
  static bool get hasTouchscreen => _hasTouchscreen;

  /// Returns `true` when the currently focused `EditableText` has been
  /// explicitly unlocked by the user pressing `Select`/`Enter`.
  static bool get isSoftKeyboardAllowed => _unlockedNode != null;

  /// Initializes TV environment detection, seeds first-launch TV defaults in
  /// `GStorage.setting`, and installs the soft-keyboard gate when `isTv`.
  static Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    if (_forceTvFromEnv) {
      _isTv = true;
      _hasTouchscreen = false;
    } else if (!kIsWeb && Platform.isAndroid) {
      try {
        final Map<Object?, Object?>? env = await _channel
            .invokeMethod<Map<Object?, Object?>>('getTvEnvironment');
        if (env != null) {
          final bool isTvUi = env['isTelevisionUiMode'] == true;
          final bool hasLeanback = env['hasLeanbackFeature'] == true;
          final bool hasTouch = env['hasTouchscreen'] != false;
          _isTv = isTvUi || hasLeanback;
          _hasTouchscreen = hasTouch;
        } else {
          final bool? legacyResult = await _channel.invokeMethod<bool>(
            'isTelevision',
          );
          _isTv = legacyResult ?? false;
          _hasTouchscreen = !_isTv;
        }
      } catch (_) {
        _isTv = false;
      }
    }

    if (isTv) {
      await _seedTvDefaultsIfNeeded();
      _installSoftKeyboardGate();
    }
  }

  /// Seeds TV defaults into [settingBox] for any keys not already set by the
  /// user. Safe to call multiple times; never overwrites existing user keys.
  static Future<void> seedTvDefaultsToBox(Box<dynamic> settingBox) async {
    final Map<String, Object> pending = <String, Object>{};
    defaultTvSettings.forEach((String key, Object value) {
      if (!settingBox.containsKey(key)) {
        pending[key] = value;
      }
    });
    if (!settingBox.containsKey(_seededMarkerKey)) {
      pending[_seededMarkerKey] = true;
    }
    if (pending.isNotEmpty) {
      await settingBox.putAll(pending);
    }
  }

  static Future<void> _seedTvDefaultsIfNeeded() async {
    try {
      await seedTvDefaultsToBox(GStorage.setting);
    } catch (_) {
      // GStorage.setting may not be initialized in isolated widget tests.
    }
  }

  static void _installSoftKeyboardGate() {
    if (_gateInstalled) return;
    _gateInstalled = true;
    _unlockedNode = null;
    TextInput.setInputControl(_gateControl);
    FocusManager.instance.addListener(_handlePrimaryFocusChanged);
  }

  static void _uninstallSoftKeyboardGate() {
    if (!_gateInstalled) return;
    _gateInstalled = false;
    _unlockedNode = null;
    FocusManager.instance.removeListener(_handlePrimaryFocusChanged);
    TextInput.restorePlatformInputControl();
  }

  static void _handlePrimaryFocusChanged() {
    final FocusNode? primary = FocusManager.instance.primaryFocus;
    if (_unlockedNode != null && primary != _unlockedNode) {
      _unlockedNode = null;
      if (isTv) {
        TextInput.setInputControl(_gateControl);
        hideSoftKeyboard().ignore();
      }
    }
  }

  /// Locates the [EditableTextState] associated with [node] (or the current
  /// primary focus if [node] is omitted), checking both ancestors and
  /// shallow descendants.
  static EditableTextState? findEditableTextState([FocusNode? node]) {
    final FocusNode? target = node ?? FocusManager.instance.primaryFocus;
    final BuildContext? context = target?.context;
    if (context == null) return null;

    final EditableTextState? ancestor = context
        .findAncestorStateOfType<EditableTextState>();
    if (ancestor != null) return ancestor;

    EditableTextState? descendant;
    void visit(Element element, int depth) {
      if (descendant != null || depth > 8) return;
      if (element is StatefulElement && element.state is EditableTextState) {
        descendant = element.state as EditableTextState;
        return;
      }
      element.visitChildren((Element child) => visit(child, depth + 1));
    }

    if (context is Element) {
      visit(context, 0);
    }
    return descendant;
  }

  /// Returns `true` when [node] (or current primary focus) belongs to an
  /// [EditableText] / `TextField`.
  static bool isFocusedOnEditableText([FocusNode? node]) =>
      findEditableTextState(node) != null;

  /// Explicitly opens the Android TV soft keyboard for the currently focused
  /// [EditableText] when the user presses `Select` / `Enter` on the remote.
  static Future<bool> requestSoftKeyboard([FocusNode? node]) async {
    final EditableTextState? editable = findEditableTextState(node);
    final FocusNode? targetNode =
        editable?.widget.focusNode ??
        node ??
        FocusManager.instance.primaryFocus;
    _unlockedNode = targetNode;
    TextInput.restorePlatformInputControl();

    if (editable != null) {
      if (!editable.widget.focusNode.hasPrimaryFocus) {
        editable.widget.focusNode.requestFocus();
      }
      SystemChannels.textInput
          .invokeMethod<void>(
            'TextInput.updateConfig',
            editable.textInputConfiguration.toJson(),
          )
          .ignore();
      editable.requestKeyboard();
    }

    SystemChannels.textInput.invokeMethod<void>('TextInput.show').ignore();
    if (!kIsWeb && Platform.isAndroid) {
      try {
        final bool? shown = await _channel.invokeMethod<bool>(
          'showSoftKeyboard',
        );
        return shown ?? true;
      } catch (_) {
        return editable != null;
      }
    }
    return editable != null;
  }

  /// Explicitly hides the soft keyboard and re-arms the TV soft-keyboard gate.
  static Future<bool> hideSoftKeyboard() async {
    _unlockedNode = null;
    if (isTv && _gateInstalled) {
      TextInput.setInputControl(_gateControl);
    }
    SystemChannels.textInput.invokeMethod<void>('TextInput.hide').ignore();
    if (!kIsWeb && Platform.isAndroid) {
      try {
        final bool? hidden = await _channel.invokeMethod<bool>(
          'hideSoftKeyboard',
        );
        return hidden ?? true;
      } catch (_) {
        return false;
      }
    }
    return false;
  }

  @visibleForTesting
  static void setTvModeForTesting(bool value) {
    _isTv = value;
    _hasTouchscreen = !value;
    _initialized = true;
    if (value) {
      _installSoftKeyboardGate();
    } else {
      _uninstallSoftKeyboardGate();
    }
  }
}
