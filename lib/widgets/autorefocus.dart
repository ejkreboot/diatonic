import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';

class AutoRefocus extends StatefulWidget {
  final FocusNode focusNode;
  final Widget child;
  final FocusOnKeyEventCallback? onKeyEvent;
  final bool skipTraversal;
  final bool canRequestFocus;
  // If true, do NOT reclaim focus when a TextField gains focus.
  final bool allowTextFieldFocus;

  const AutoRefocus({
    super.key,
    required this.focusNode,
    required this.child,
    this.onKeyEvent,
    this.skipTraversal = true,
    this.canRequestFocus = true,
  this.allowTextFieldFocus = true,
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
    final context = currentFocus?.context;
    // Detect if an EditableText (TextField, TextFormField, etc.) is in the focus ancestry
    bool editableHasFocus = false;
    if (context != null) {
      // Direct widget check
      if (context.widget is EditableText) {
        editableHasFocus = true;
      } else {
        // Ancestor state check (covers internal focus nodes inside TextField)
        final editableState = context.findAncestorStateOfType<EditableTextState>();
        if (editableState != null) {
          editableHasFocus = true;
        }
      }
    }

    if (editableHasFocus && widget.allowTextFieldFocus) {
      return; // Let text fields keep focus
    }

  if (!widget.focusNode.hasFocus && !editableHasFocus) {
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
