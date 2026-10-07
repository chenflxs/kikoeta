import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data.dart';
import '../theme.dart';

class PlaybackSeekSecondsControl extends StatefulWidget {
  final String label;
  final int value;
  final ValueChanged<int> onChanged;

  const PlaybackSeekSecondsControl({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  State<PlaybackSeekSecondsControl> createState() =>
      _PlaybackSeekSecondsControlState();
}

class _PlaybackSeekSecondsControlState
    extends State<PlaybackSeekSecondsControl> {
  late final TextEditingController _controller;
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: '${widget.value}');
    _focusNode.addListener(_onFocusChanged);
  }

  @override
  void didUpdateWidget(PlaybackSeekSecondsControl oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value && !_focusNode.hasFocus) {
      _showValue(widget.value);
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChanged);
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  int get _draftValue => AppState.normalizePlaybackSeekSeconds(
    int.tryParse(_controller.text) ?? widget.value,
  );

  void _showValue(int value) {
    final text = '$value';
    _controller.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }

  void _saveValue(int value) {
    final normalized = AppState.normalizePlaybackSeekSeconds(value);
    _showValue(normalized);
    if (normalized != widget.value) widget.onChanged(normalized);
  }

  void _onFocusChanged() {
    if (!_focusNode.hasFocus) _saveValue(_draftValue);
  }

  @override
  Widget build(BuildContext context) {
    final p = Theme.of(context).brightness == Brightness.dark
        ? AppColors.dark
        : AppColors.light;
    return TextFieldTapRegion(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: '减少${widget.label}秒数',
            onPressed: widget.value > AppState.playbackSeekMinSeconds
                ? () =>
                      _saveValue(_draftValue - AppState.playbackSeekStepSeconds)
                : null,
            icon: const Icon(Icons.remove, size: 18),
            color: p.accent,
          ),
          SizedBox(
            width: 48,
            child: TextField(
              controller: _controller,
              focusNode: _focusNode,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.done,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: p.text),
              decoration: InputDecoration(
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                filled: true,
                fillColor: p.surface2,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: p.border),
                ),
              ),
              // 保存规范值，编辑中的文本留到提交或失焦时再显示取整结果。
              onChanged: (text) {
                final value = int.tryParse(text);
                if (value == null) return;
                final normalized = AppState.normalizePlaybackSeekSeconds(value);
                if (normalized != widget.value) widget.onChanged(normalized);
              },
              onSubmitted: (_) => _saveValue(_draftValue),
              onTapOutside: (_) => _focusNode.unfocus(),
            ),
          ),
          IconButton(
            tooltip: '增加${widget.label}秒数',
            onPressed: widget.value < AppState.playbackSeekMaxSeconds
                ? () =>
                      _saveValue(_draftValue + AppState.playbackSeekStepSeconds)
                : null,
            icon: const Icon(Icons.add, size: 18),
            color: p.accent,
          ),
        ],
      ),
    );
  }
}
