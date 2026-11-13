import 'package:flutter/material.dart';

import '../smooth_scroll.dart';
import '../theme.dart';

Palette _p(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
    ? AppColors.dark
    : AppColors.light;

Widget formSheet({
  required BuildContext context,
  required String title,
  String? sub,
  required List<Widget> children,
}) {
  final p = _p(context);
  return SafeArea(
    child: SmoothSingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 22),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: p.surface3,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
          if (sub != null) ...[
            const SizedBox(height: 4),
            Text(sub, style: TextStyle(fontSize: 12, color: p.muted)),
          ],
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    ),
  );
}

Widget sheetField(
  BuildContext context,
  String label,
  TextEditingController ctrl, {
  String? hint,
  bool obscure = false,
  bool enabled = true,
  Widget? suffix,
  TextInputAction? textInputAction,
  ValueChanged<String>? onSubmitted,
  ValueChanged<String>? onChanged,
}) {
  final p = _p(context);
  return Padding(
    padding: const EdgeInsets.only(bottom: 13),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: p.muted,
            ),
          ),
        ),
        TextField(
          controller: ctrl,
          enabled: enabled,
          obscureText: obscure,
          textInputAction: textInputAction,
          onSubmitted: onSubmitted,
          onChanged: onChanged,
          style: TextStyle(fontSize: 13, color: p.text),
          decoration: InputDecoration(
            hintText: hint,
            suffixIcon: suffix,
            hintStyle: TextStyle(fontSize: 13, color: p.dim),
            filled: true,
            fillColor: p.surface2,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(11),
              borderSide: BorderSide(color: p.line),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(11),
              borderSide: BorderSide(color: p.line),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(11),
              borderSide: BorderSide(color: p.accent),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 11,
            ),
          ),
        ),
      ],
    ),
  );
}

ButtonStyle formSheetActionStyle(Palette p) => ElevatedButton.styleFrom(
  backgroundColor: p.accent,
  foregroundColor: Colors.white,
  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
  padding: const EdgeInsets.symmetric(vertical: 12),
  textStyle: const TextStyle(fontWeight: FontWeight.w600),
);
