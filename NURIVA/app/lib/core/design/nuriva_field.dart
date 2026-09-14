import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nuriva/core/design/nuriva_tokens.dart';

/// NURIVA's text input.
///
/// Wraps [TextFormField] so that every input in the app shares one label
/// treatment, one error presentation and one set of paddings. Module 02's
/// login and registration forms are its first consumers.
final class NurivaTextField extends StatefulWidget {
  const NurivaTextField({
    required this.label,
    this.controller,
    this.hint,
    this.helper,
    this.initialValue,
    this.keyboardType,
    this.textInputAction,
    this.obscure = false,
    this.enabled = true,
    this.autofocus = false,
    this.maxLines = 1,
    this.prefixIcon,
    this.validator,
    this.onChanged,
    this.onSubmitted,
    this.inputFormatters,
    this.autofillHints,
    super.key,
  });

  final String label;
  final TextEditingController? controller;
  final String? hint;

  /// Guidance shown below the field while it is valid.
  final String? helper;

  final String? initialValue;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;

  /// Renders a password field with a reveal toggle.
  final bool obscure;

  final bool enabled;
  final bool autofocus;
  final int maxLines;
  final IconData? prefixIcon;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final List<TextInputFormatter>? inputFormatters;
  final Iterable<String>? autofillHints;

  @override
  State<NurivaTextField> createState() => _NurivaTextFieldState();
}

class _NurivaTextFieldState extends State<NurivaTextField> {
  late bool _hidden = widget.obscure;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // A persistent label above the field, rather than a floating one.
        // Floating labels vanish once a field is filled, which removes the
        // context an elderly user needs when reviewing a long form.
        Padding(
          padding: const EdgeInsets.only(
            left: NurivaTokens.space1,
            bottom: NurivaTokens.space2,
          ),
          child: Text(
            widget.label,
            style: context.text.titleMedium?.copyWith(
              color: widget.enabled ? scheme.onSurface : scheme.outline,
            ),
          ),
        ),
        TextFormField(
          controller: widget.controller,
          initialValue: widget.controller == null ? widget.initialValue : null,
          keyboardType: widget.keyboardType,
          textInputAction: widget.textInputAction,
          obscureText: _hidden,
          enabled: widget.enabled,
          autofocus: widget.autofocus,
          maxLines: widget.obscure ? 1 : widget.maxLines,
          validator: widget.validator,
          onChanged: widget.onChanged,
          onFieldSubmitted: widget.onSubmitted,
          inputFormatters: widget.inputFormatters,
          autofillHints: widget.autofillHints,
          style: context.text.bodyLarge,
          decoration: InputDecoration(
            hintText: widget.hint,
            helperText: widget.helper,
            helperMaxLines: 2,
            errorMaxLines: 3,
            prefixIcon: widget.prefixIcon == null
                ? null
                : Icon(widget.prefixIcon, color: scheme.onSurfaceVariant),
            suffixIcon: widget.obscure
                ? IconButton(
                    onPressed: () => setState(() => _hidden = !_hidden),
                    icon: Icon(
                      _hidden
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      color: scheme.onSurfaceVariant,
                    ),
                    tooltip: _hidden ? 'Show' : 'Hide',
                  )
                : null,
          ),
        ),
      ],
    );
  }
}
