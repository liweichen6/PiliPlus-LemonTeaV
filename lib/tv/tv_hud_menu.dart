part of 'tv_player_hud.dart';

// The HUD's `⋮` menu and the button editor (M14.3, docs/tv/PLAN.md,
// Milestone M14). Both open as dialogs over the HUD, which stays visible
// behind them with its auto-hide paused.

/// The `⋮` menu: every entry of the action table that's available now,
/// grouped as agreed, in a panel at the right of the screen. Choosing an entry
/// closes the menu and returns its button, which the HUD then runs.
class _TvHudMenuPanel extends StatelessWidget {
  const _TvHudMenuPanel({
    required this.source,
    required this.tripleAnimation,
  });

  final TvHudActionSource source;
  final Animation<double> tripleAnimation;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: Material(
        key: TvPlayerHud.menuPanelKey,
        color: const Color(0xF21A1C1E),
        child: SizedBox(
          width: 340,
          height: double.infinity,
          child: SafeArea(
            left: false,
            // The labels and availability read the controllers' Rx values.
            child: Obx(() {
              bool first = true;
              final List<Widget> children = [];
              for (final TvHudMenuGroup group in TvHudMenuGroup.values) {
                final List<TvHudAction> actions = [
                  for (final TvHudActionId id in TvHudActionId.values)
                    if (id.group == group) ...source.resolveAction(id),
                ];
                if (actions.isEmpty) continue;
                children.add(
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 12, 4, 6),
                    child: Text(
                      group.label,
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                );
                for (final TvHudAction action in actions) {
                  children.add(
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: _entry(context, action, autofocus: first),
                    ),
                  );
                  first = false;
                }
              }
              return SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: children,
                ),
              );
            }),
          ),
        ),
      ),
    );
  }

  Widget _entry(
    BuildContext context,
    TvHudAction action, {
    required bool autofocus,
  }) {
    final Key key = TvPlayerHud.menuEntryKey(action.buttonId);
    if (action.onHoldStart != null && action.onHoldEnd != null) {
      return _TvTripleLikePill(
        key: key,
        autofocus: autofocus,
        alignment: Alignment.centerLeft,
        icon: action.icon,
        label: action.label,
        active: action.active,
        tripleAnimation: tripleAnimation,
        onStartTriple: action.onHoldStart!,
        onCancelTriple: (bool isTapUp) {
          action.onHoldEnd!(isTapUp);
          if (isTapUp) Navigator.of(context).pop();
        },
      );
    }
    return _TvHudPillButton(
      key: key,
      autofocus: autofocus,
      alignment: Alignment.centerLeft,
      icon: action.icon,
      label: action.label,
      active: action.active,
      onPressed: () => Navigator.of(context).pop(action),
    );
  }
}

enum _TvHudEditorRow { topRight, bottom, unpinned }

/// The button editor (agreed with the user, 2026-11-07): a top row with
/// `显示按钮文字`, `恢复默认` and `完成`, then the rows 右上角, 底部 and 未固定.
/// Select picks a button up; while it's carried, Left and Right move it along
/// its row and Up and Down move it to the end of the row above or below.
/// Select or Back puts it down. Every change is passed to [onChanged] at once.
class _TvHudEditor extends StatefulWidget {
  const _TvHudEditor({required this.initial, required this.onChanged});

  final TvHudGroups initial;
  final ValueChanged<TvHudGroups> onChanged;

  @override
  State<_TvHudEditor> createState() => _TvHudEditorState();
}

class _TvHudEditorState extends State<_TvHudEditor> {
  late TvHudGroups _groups = widget.initial;
  TvHudActionId? _carried;

  // Global keys let a button keep its element, and so its focus, when it
  // moves to another row.
  final Map<TvHudActionId, GlobalKey> _keys = {};
  final Map<TvHudActionId, FocusNode> _nodes = {};
  final FocusNode _cancelResetNode = FocusNode(debugLabel: 'TvHudEditor 取消');

  @override
  void initState() {
    super.initState();
    // Asked for explicitly: the engine's first-focus pick skips buttons in a
    // scroll view that hasn't laid out yet, and would take the top row.
    final TvHudActionId? first =
        _groups.topRight.firstOrNull ?? _groups.bottom.firstOrNull;
    if (first != null) _focusAfterFrame(_nodeOf(first));
  }

  void _focusAfterFrame(FocusNode node) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && node.context != null) node.requestFocus();
    });
  }

  GlobalKey _keyOf(TvHudActionId id) =>
      _keys.putIfAbsent(id, () => GlobalKey(debugLabel: 'tvHudEditor:$id'));

  FocusNode _nodeOf(TvHudActionId id) => _nodes.putIfAbsent(
    id,
    () => FocusNode(debugLabel: 'TvHudEditor ${id.title}'),
  );

  @override
  void dispose() {
    for (final FocusNode node in _nodes.values) {
      node.dispose();
    }
    _cancelResetNode.dispose();
    super.dispose();
  }

  _TvHudEditorRow _rowOf(TvHudActionId id) => _groups.topRight.contains(id)
      ? _TvHudEditorRow.topRight
      : _groups.bottom.contains(id)
      ? _TvHudEditorRow.bottom
      : _TvHudEditorRow.unpinned;

  void _update(TvHudGroups next, {TvHudActionId? follow}) {
    setState(() => _groups = next);
    widget.onChanged(next);
    if (follow == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final FocusNode node = _nodeOf(follow);
      if (!node.hasPrimaryFocus) node.requestFocus();
      final BuildContext? itemContext = _keyOf(follow).currentContext;
      if (itemContext != null && itemContext.mounted) {
        Scrollable.ensureVisible(
          itemContext,
          alignment: 0.5,
          alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
        );
      }
    });
  }

  void _shift(TvHudActionId id, int delta) {
    final _TvHudEditorRow row = _rowOf(id);
    if (row == _TvHudEditorRow.unpinned) return;
    final List<TvHudActionId> list = [
      ...(row == _TvHudEditorRow.topRight ? _groups.topRight : _groups.bottom),
    ];
    final int from = list.indexOf(id);
    final int to = from + delta;
    if (to < 0 || to >= list.length) return;
    list
      ..[from] = list[to]
      ..[to] = id;
    _update(
      row == _TvHudEditorRow.topRight
          ? _groups.copyWith(topRight: list)
          : _groups.copyWith(bottom: list),
      follow: id,
    );
  }

  void _moveRow(TvHudActionId id, {required bool up}) {
    final List<TvHudActionId> top = [..._groups.topRight];
    final List<TvHudActionId> bottom = [..._groups.bottom];
    switch ((_rowOf(id), up)) {
      case (_TvHudEditorRow.bottom, true):
        if (top.length >= TvHudGroups.maxTopRight) {
          SmartDialog.showToast('右上角最多 ${TvHudGroups.maxTopRight} 个');
          return;
        }
        bottom.remove(id);
        top.add(id);
      case (_TvHudEditorRow.unpinned, true):
        bottom.add(id);
      case (_TvHudEditorRow.topRight, false):
        top.remove(id);
        bottom.add(id);
      case (_TvHudEditorRow.bottom, false):
        bottom.remove(id);
      case (_TvHudEditorRow.topRight, true) ||
          (_TvHudEditorRow.unpinned, false):
        return;
    }
    _update(
      _groups.copyWith(topRight: top, bottom: bottom),
      follow: id,
    );
  }

  KeyEventResult _onItemKey(TvHudActionId id, KeyEvent event) {
    final LogicalKeyboardKey key = event.logicalKey;
    if (_isSelectKey(key)) {
      if (event is KeyDownEvent) {
        setState(() => _carried = _carried == id ? null : id);
      }
      return KeyEventResult.handled;
    }
    if (_carried != id) return KeyEventResult.ignored;
    final bool press = event is KeyDownEvent || event is KeyRepeatEvent;
    if (key == LogicalKeyboardKey.arrowLeft) {
      if (press) _shift(id, -1);
    } else if (key == LogicalKeyboardKey.arrowRight) {
      if (press) _shift(id, 1);
    } else if (key == LogicalKeyboardKey.arrowUp) {
      if (press) _moveRow(id, up: true);
    } else if (key == LogicalKeyboardKey.arrowDown) {
      if (press) _moveRow(id, up: false);
    } else {
      return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  void _toggleLabels() =>
      _update(_groups.copyWith(showLabels: !_groups.showLabels));

  Future<void> _confirmReset() async {
    _focusAfterFrame(_cancelResetNode);
    final bool? reset = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        backgroundColor: const Color(0xF21A1C1E),
        title: const Text(
          '恢复默认按钮？',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        content: const Text(
          '右上角、底部和显示按钮文字都会恢复默认。',
          style: TextStyle(color: Colors.white70, fontSize: 14),
        ),
        actions: [
          _TvHudPillButton(
            key: TvPlayerHud.editorResetConfirmKey,
            compact: true,
            label: '恢复',
            onPressed: () => Navigator.of(dialogContext).pop(true),
          ),
          // Focus starts on 取消, so a stray Select changes nothing.
          _TvHudPillButton(
            focusNode: _cancelResetNode,
            compact: true,
            autofocus: true,
            label: '取消',
            onPressed: () => Navigator.of(dialogContext).pop(false),
          ),
        ],
      ),
    );
    if (reset != true || !mounted) return;
    _carried = null;
    _update(TvHudGroups.defaults);
    SmartDialog.showToast('已恢复默认按钮');
  }

  Widget _item(TvHudActionId id, {required bool autofocus}) {
    return _TvHudEditorItem(
      key: _keyOf(id),
      id: id,
      focusNode: _nodeOf(id),
      autofocus: autofocus,
      carried: _carried == id,
      onKeyEvent: (_, KeyEvent event) => _onItemKey(id, event),
      onFocusLost: () {
        if (_carried == id) setState(() => _carried = null);
      },
    );
  }

  static const TextStyle _rowTitleStyle = TextStyle(
    color: Colors.white70,
    fontSize: 14,
    fontWeight: FontWeight.w600,
  );

  Widget _rowTitle(String text) => Padding(
    padding: const EdgeInsets.only(top: 14, bottom: 8),
    child: Text(text, style: _rowTitleStyle),
  );

  static const Widget _empty = Padding(
    padding: EdgeInsets.symmetric(vertical: 8),
    child: Text('（空）', style: TextStyle(color: Colors.white38, fontSize: 13)),
  );

  @override
  Widget build(BuildContext context) {
    final TvHudGroups groups = _groups;
    final TvHudActionId? firstPinned =
        groups.topRight.firstOrNull ?? groups.bottom.firstOrNull;
    final List<TvHudActionId> unpinned = groups.unpinned;
    final TvHudActionId? carried = _carried;

    return PopScope(
      canPop: carried == null,
      onPopInvokedWithResult: (bool didPop, _) {
        if (!didPop) setState(() => _carried = null);
      },
      child: Center(
        child: Material(
          key: TvPlayerHud.editorKey,
          color: const Color(0xF21A1C1E),
          borderRadius: BorderRadius.circular(16),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 860,
              maxHeight: MediaQuery.sizeOf(context).height * 0.92,
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 18, 24, 14),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    spacing: 10,
                    children: [
                      const Expanded(
                        child: Text(
                          '编辑按钮',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      _TvHudPillButton(
                        key: TvPlayerHud.editorShowLabelsKey,
                        compact: true,
                        autofocus: firstPinned == null,
                        active: groups.showLabels,
                        icon: groups.showLabels
                            ? Icons.check_box_rounded
                            : Icons.check_box_outline_blank_rounded,
                        label: '显示按钮文字: ${groups.showLabels ? '开' : '关'}',
                        onPressed: _toggleLabels,
                      ),
                      _TvHudPillButton(
                        key: TvPlayerHud.editorResetKey,
                        compact: true,
                        icon: Icons.restore_rounded,
                        label: '恢复默认',
                        onPressed: _confirmReset,
                      ),
                      _TvHudPillButton(
                        key: TvPlayerHud.editorDoneKey,
                        compact: true,
                        icon: Icons.done_rounded,
                        label: '完成',
                        onPressed: () => Navigator.of(context).maybePop(),
                      ),
                    ],
                  ),
                  Flexible(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _rowTitle(
                            '右上角 ${groups.topRight.length}/'
                            '${TvHudGroups.maxTopRight}',
                          ),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              for (final TvHudActionId id in groups.topRight)
                                _item(id, autofocus: id == firstPinned),
                              // The `⋮` button always comes last and can't be
                              // moved, so it isn't focusable here.
                              const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 6),
                                child: Icon(
                                  Icons.more_vert_rounded,
                                  color: Colors.white38,
                                  size: 20,
                                ),
                              ),
                            ],
                          ),
                          _rowTitle('底部'),
                          if (groups.bottom.isEmpty)
                            _empty
                          else
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                for (final TvHudActionId id in groups.bottom)
                                  _item(id, autofocus: id == firstPinned),
                              ],
                            ),
                          _rowTitle('未固定'),
                          if (unpinned.isEmpty) _empty,
                          for (final TvHudMenuGroup group
                              in TvHudMenuGroup.values)
                            if (unpinned.any((id) => id.group == group))
                              Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    SizedBox(
                                      width: 92,
                                      child: Padding(
                                        padding: const EdgeInsets.only(top: 9),
                                        child: Text(
                                          group.label,
                                          style: const TextStyle(
                                            color: Colors.white54,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      child: Wrap(
                                        spacing: 8,
                                        runSpacing: 8,
                                        children: [
                                          for (final TvHudActionId id
                                              in unpinned)
                                            if (id.group == group)
                                              _item(id, autofocus: false),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    carried == null
                        ? 'OK 拿起按钮 · 返回 关闭'
                        : '正在移动「${carried.title}」 · ◀ ▶ 移动 · ▲ ▼ 换行 · '
                              'OK 或 返回 放下',
                    key: TvPlayerHud.editorHintKey,
                    style: const TextStyle(color: Colors.white54, fontSize: 13),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A button in the editor: always its icon and name. A carried button is
/// drawn raised.
class _TvHudEditorItem extends StatefulWidget {
  const _TvHudEditorItem({
    super.key,
    required this.id,
    required this.focusNode,
    required this.autofocus,
    required this.carried,
    required this.onKeyEvent,
    required this.onFocusLost,
  });

  final TvHudActionId id;
  final FocusNode focusNode;
  final bool autofocus;
  final bool carried;
  final FocusOnKeyEventCallback onKeyEvent;
  final VoidCallback onFocusLost;

  @override
  State<_TvHudEditorItem> createState() => _TvHudEditorItemState();
}

class _TvHudEditorItemState extends State<_TvHudEditorItem> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final Color primary = Theme.of(context).colorScheme.primary;
    final bool carried = widget.carried;
    return KeyedSubtree(
      key: TvPlayerHud.editorItemKey(widget.id),
      child: Focus(
        focusNode: widget.focusNode,
        autofocus: widget.autofocus,
        onKeyEvent: widget.onKeyEvent,
        onFocusChange: (bool hasFocus) {
          setState(() => _focused = hasFocus);
          if (!hasFocus) widget.onFocusLost();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: carried
                ? primary
                : _focused
                ? primary.withValues(alpha: 0.55)
                : const Color(0x33FFFFFF),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: carried || _focused ? Colors.white : Colors.white24,
              width: carried ? 2.6 : (_focused ? 2.2 : 1.2),
            ),
            boxShadow: carried
                ? const [
                    BoxShadow(
                      color: Color(0xAA000000),
                      blurRadius: 12,
                      offset: Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            spacing: 6,
            children: [
              Icon(
                carried ? Icons.open_with_rounded : widget.id.icon,
                size: 16,
                color: Colors.white,
              ),
              Text(
                widget.id.title,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: carried || _focused
                      ? FontWeight.w700
                      : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
