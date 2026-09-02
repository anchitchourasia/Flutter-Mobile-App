import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

enum TextTransform { none, uppercase, lowercase }

class PassSection extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? badge;
  final List<Widget> children;

  const PassSection({
    super.key,
    required this.icon,
    required this.title,
    this.badge,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFC8D6E8), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF0F2040), Color(0xFF1A3560)],
              ),
              border: Border(
                bottom: BorderSide(color: Color(0xFF1E3A6E), width: 1.5),
              ),
            ),
            child: Row(
              children: [
                Icon(icon, size: 18, color: Colors.white),
                const SizedBox(width: 6),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: 1.2,
                  ),
                ),
                if (badge != null) ...[
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(38),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: Colors.white.withAlpha(76)),
                    ),
                    child: Text(
                      badge!,
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: children,
            ),
          ),
        ],
      ),
    );
  }
}

class PassGrid2 extends StatelessWidget {
  final List<Widget> children;

  const PassGrid2({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    return Wrap(spacing: 16, runSpacing: 12, children: children);
  }
}

class PassGrid3 extends StatelessWidget {
  final List<Widget> children;

  const PassGrid3({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    return Wrap(spacing: 16, runSpacing: 12, children: children);
  }
}

class PassField extends StatelessWidget {
  final String label;
  final String? hintText;
  final String? initialValue;
  final TextEditingController? controller;
  final bool readOnly;
  final int? maxLines;
  final TextTransform textTransform;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final Widget? suffix;
  final String? hintTextExtra;
  final String? placeholder;
  final double? width;

  const PassField({
    super.key,
    required this.label,
    this.hintText,
    this.initialValue,
    this.controller,
    this.readOnly = false,
    this.maxLines = 1,
    this.textTransform = TextTransform.none,
    this.onChanged,
    this.onSubmitted,
    this.suffix,
    this.hintTextExtra,
    this.placeholder,
    this.width,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveController =
        controller ?? TextEditingController(text: initialValue);

    return SizedBox(
      width: width ?? 220,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1E3A6E),
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 4),
          TextField(
            controller: effectiveController,
            readOnly: readOnly,
            maxLines: maxLines,
            decoration: InputDecoration(
              hintText: hintText ?? placeholder,
              hintStyle: TextStyle(
                fontSize: 12,
                color: readOnly
                    ? const Color(0xFF64748B)
                    : const Color(0xFFB0BEC5),
              ),
              filled: true,
              fillColor: readOnly
                  ? const Color(0xFFEEF2F7)
                  : const Color(0xFFF8FAFD),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 8,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(
                  color: Color(0xFFC8D6E8),
                  width: 1.5,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(
                  color: Color(0xFF2563EB),
                  width: 1.5,
                ),
              ),
              suffixIcon: suffix,
            ),
            inputFormatters: [
              if (textTransform == TextTransform.uppercase)
                FilteringTextInputFormatter.allow(RegExp(r'[^\s]')),
              LengthLimitingTextInputFormatter(60),
            ],
            onChanged: (v) {
              String transformed = v;
              if (textTransform == TextTransform.uppercase) {
                transformed = v.toUpperCase();
                if (effectiveController.text != transformed) {
                  final pos = effectiveController.selection.baseOffset;
                  effectiveController.text = transformed;
                  effectiveController.selection = TextSelection.collapsed(
                    offset: pos < 0 ? 0 : pos,
                  );
                }
              } else if (textTransform == TextTransform.lowercase) {
                transformed = v.toLowerCase();
              }

              if (onChanged != null) {
                onChanged!(transformed);
              }
            },
            onSubmitted: onSubmitted,
          ),
          if (hintTextExtra != null) ...[
            const SizedBox(height: 3),
            Text(
              hintTextExtra!,
              style: const TextStyle(
                fontSize: 10,
                color: Color(0xFF94A3B8),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class PassDropdown extends StatelessWidget {
  final String label;
  final String? value;
  final List<String> items;
  final String hint;
  final ValueChanged<String?>? onChanged;
  final double? width;

  const PassDropdown({
    super.key,
    required this.label,
    required this.value,
    required this.items,
    required this.hint,
    this.onChanged,
    this.width,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onChanged != null;
    return SizedBox(
      width: width ?? 220,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1E3A6E),
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 4),
          DropdownButtonFormField<String>(
            initialValue: value,
            isExpanded: true,
            decoration: InputDecoration(
              filled: true,
              fillColor: enabled
                  ? const Color(0xFFF8FAFD)
                  : const Color(0xFFEEF2F7),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 8,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(
                  color: Color(0xFFC8D6E8),
                  width: 1.5,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(
                  color: Color(0xFF2563EB),
                  width: 1.5,
                ),
              ),
            ),
            items: items
                .map(
                  (e) => DropdownMenuItem(
                    value: e,
                    child: Text(
                      e,
                      style: const TextStyle(fontSize: 12),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                )
                .toList(),
            hint: Text(
              hint,
              style: const TextStyle(fontSize: 12, color: Color(0xFFB0BEC5)),
              overflow: TextOverflow.ellipsis,
            ),
            onChanged: enabled ? onChanged : null,
          ),
        ],
      ),
    );
  }
}

class PassDropdownSmall extends StatelessWidget {
  final String? value;
  final List<String> items;
  final String hint;
  final ValueChanged<String?>? onChanged;

  const PassDropdownSmall({
    super.key,
    required this.value,
    required this.items,
    required this.hint,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onChanged != null;
    return DropdownButtonFormField<String>(
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(
        filled: true,
        fillColor: enabled ? const Color(0xFFF8FAFD) : const Color(0xFFEEF2F7),
        contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: Color(0xFFC8D6E8), width: 1.2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.2),
        ),
      ),
      items: items
          .map(
            (e) => DropdownMenuItem(
              value: e,
              child: Text(
                e,
                style: const TextStyle(fontSize: 11),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          )
          .toList(),
      hint: Text(
        hint,
        style: const TextStyle(fontSize: 11, color: Color(0xFFB0BEC5)),
        overflow: TextOverflow.ellipsis,
      ),
      onChanged: enabled ? onChanged : null,
    );
  }
}

class PassFieldSmall extends StatelessWidget {
  final String? hintText;
  final String? initialValue;
  final bool readOnly;
  final TextTransform textTransform;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;

  const PassFieldSmall({
    super.key,
    this.hintText,
    this.initialValue,
    this.readOnly = false,
    this.textTransform = TextTransform.none,
    this.onChanged,
    this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    final ctrl = TextEditingController(text: initialValue);
    return TextField(
      key: ValueKey(initialValue),
      controller: ctrl,
      readOnly: readOnly,
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: const TextStyle(fontSize: 11, color: Color(0xFFB0BEC5)),
        filled: true,
        fillColor: readOnly ? const Color(0xFFEEF2F7) : const Color(0xFFF8FAFD),
        contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: Color(0xFFC8D6E8), width: 1.2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.2),
        ),
      ),
      onChanged: (v) {
        String transformed = v;
        if (textTransform == TextTransform.uppercase) {
          transformed = v.toUpperCase();
          if (ctrl.text != transformed) {
            final pos = ctrl.selection.baseOffset;
            ctrl.text = transformed;
            ctrl.selection = TextSelection.collapsed(offset: pos < 0 ? 0 : pos);
          }
        } else if (textTransform == TextTransform.lowercase) {
          transformed = v.toLowerCase();
        }

        if (onChanged != null) {
          onChanged!(transformed);
        }
      },
      onSubmitted: onSubmitted,
    );
  }
}

class PassDateFieldSmall extends StatelessWidget {
  final String? value;
  final bool enabled;
  final ValueChanged<String> onDateSelected;

  const PassDateFieldSmall({
    super.key,
    this.value,
    this.enabled = true,
    required this.onDateSelected,
  });

  Future<void> _pickDate(BuildContext context) async {
    if (!enabled) return;
    DateTime? initialDate;
    if (value != null && value!.length >= 10) {
      try {
        final parts = value!.split('-');
        initialDate = DateTime(
          int.parse(parts[0]),
          int.parse(parts[1]),
          int.parse(parts[2]),
        );
      } catch (_) {
        initialDate = DateTime.now();
      }
    }

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 10)),
    );

    if (picked != null) {
      final dd = picked.day.toString().padLeft(2, '0');
      final mm = picked.month.toString().padLeft(2, '0');
      final yyyy = picked.year.toString();
      onDateSelected('$yyyy-$mm-$dd');
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _pickDate(context),
      child: IgnorePointer(
        ignoring: !enabled,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          decoration: BoxDecoration(
            color: enabled ? const Color(0xFFF8FAFD) : const Color(0xFFEEF2F7),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: enabled
                  ? const Color(0xFFC8D6E8)
                  : const Color(0xFFB0BEC5),
              width: 1.2,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  value ?? '',
                  style: const TextStyle(fontSize: 11),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const Icon(
                Icons.calendar_today,
                size: 14,
                color: Color(0xFF1D6FD8),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class PassActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color backgroundColor;
  final Color foregroundColor;
  final VoidCallback? onPressed;

  const PassActionButton({
    super.key,
    required this.label,
    required this.icon,
    required this.backgroundColor,
    required this.foregroundColor,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 16),
      label: Text(
        label,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: backgroundColor,
        foregroundColor: foregroundColor,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}
