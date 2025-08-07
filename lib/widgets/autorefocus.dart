import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';

class AutoRefocus extends StatefulWidget {
  final FocusNode focusNode;
  final Widget child;
  final FocusOnKeyEventCallback? onKeyEvent;
  final bool skipTraversal;
  final bool canRequestFocus;

  const AutoRefocus({
    super.key,
    required this.focusNode,
    required this.child,
    this.onKeyEvent,
    this.skipTraversal = true,
    this.canRequestFocus = true,
  });

  @override
  State<AutoRefocus> createState() => _AutoRefocusState();
}

class _AutoRefocusState extends State<AutoRefocus> {
  @override
  void initState() {
    super.initState();
    FocusManager.instance.addListener(_handleFocusChange);
  }

void _handleFocusChange() {
  final currentFocus = FocusManager.instance.primaryFocus;
  final focusedWidget = currentFocus?.context?.widget;
  final editableHasFocus = focusedWidget is EditableText;

  // Reclaim focus if:
  // 1. We're not focused
  // 2. No editable widget has focus
  if (!widget.focusNode.hasFocus && !editableHasFocus) {
    debugPrint('Reclaiming focus for: ${widget.focusNode}');
    widget.focusNode.requestFocus();
  }
}

  @override
  void dispose() {
    FocusManager.instance.removeListener(_handleFocusChange);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: widget.focusNode,
      autofocus: true,
      skipTraversal: widget.skipTraversal,
      canRequestFocus: widget.canRequestFocus,
      onKeyEvent: widget.onKeyEvent,
      child: widget.child,
    );
  }
}
