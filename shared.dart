import 'package:flutter/material.dart';

import '../core/design_tokens.dart';

class ModuleHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final String icon;
  final List<Widget> actions;

  const ModuleHeader({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    this.actions = const [],
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(
        color: C.elevated,
        border: Border(bottom: BorderSide(color: C.border)),
      ),
      child: Row(
        children: [
          Text(icon, style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: C.tx1,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                subtitle,
                style: const TextStyle(color: C.tx3, fontSize: 10),
              ),
            ],
          ),
          const Spacer(),
          ...actions,
        ],
      ),
    );
  }
}

class HeaderChip extends StatelessWidget {
  final String label;
  final Color color;

  const HeaderChip({super.key, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

class SectionCard extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const SectionCard({super.key, required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: C.elevated,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: C.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: C.tx2,
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}

class FieldRow extends StatelessWidget {
  final String label;
  final String hint;
  final TextEditingController ctrl;
  final IconData icon;
  final bool obscure;

  const FieldRow({
    super.key,
    required this.label,
    required this.hint,
    required this.ctrl,
    required this.icon,
    this.obscure = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: C.tx3,
            fontSize: 10,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 5),
        TextField(
          controller: ctrl,
          obscureText: obscure,
          style: const TextStyle(
            color: C.tx1,
            fontSize: 12,
            fontFamily: 'monospace',
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: C.tx3, fontSize: 12),
            prefixIcon: Icon(icon, size: 15, color: C.tx3),
            filled: true,
            fillColor: C.card,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: C.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: C.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: C.gold),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 10,
            ),
          ),
        ),
      ],
    );
  }
}

class EnumDropdown extends StatefulWidget {
  final String label;
  final String value;
  final List<String> options;

  const EnumDropdown({
    super.key,
    required this.label,
    required this.value,
    required this.options,
  });

  @override
  State<EnumDropdown> createState() => _EnumDropdownState();
}

class _EnumDropdownState extends State<EnumDropdown> {
  late String _val;

  @override
  void initState() {
    super.initState();
    _val = widget.value;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.label,
          style: const TextStyle(color: C.tx3, fontSize: 10),
        ),
        const SizedBox(height: 5),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: C.card,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: C.border),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _val,
              isExpanded: true,
              dropdownColor: C.card,
              style: const TextStyle(color: C.tx1, fontSize: 12),
              items: widget.options
                  .map((o) => DropdownMenuItem(value: o, child: Text(o)))
                  .toList(),
              onChanged: (v) {
                if (v != null) setState(() => _val = v);
              },
            ),
          ),
        ),
      ],
    );
  }
}

class SliderField extends StatelessWidget {
  final String label;
  final double value;
  final ValueChanged<double> onChanged;
  final Color color;

  const SliderField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(label, style: const TextStyle(color: C.tx2, fontSize: 11)),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '${(value * 100).toStringAsFixed(0)}%',
                style: TextStyle(
                  color: color,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        Slider(
          value: value.clamp(0.0, 1.0),
          onChanged: onChanged,
        ),
      ],
    );
  }
}

class GoldBtn extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final bool filled;
  final Color color;

  const GoldBtn({
    super.key,
    required this.label,
    required this.onTap,
    this.filled = false,
    this.color = C.gold,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 13),
        decoration: BoxDecoration(
          color: filled ? color : color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: filled ? Colors.transparent : color.withValues(alpha: 0.5),
          ),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: filled ? Colors.black : color,
            fontSize: 13,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }
}

class OutlineBtn extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;

  const OutlineBtn({
    super.key,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.5)),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

class SectionTag extends StatelessWidget {
  final String label;
  final Color color;

  const SectionTag({super.key, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(12),
          bottomRight: Radius.circular(8),
        ),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 9,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.5,
        ),
      ),
    );
  }
}

class Pill extends StatelessWidget {
  final String label;
  final Color color;

  const Pill({super.key, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 9,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

class StatRow extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const StatRow(
    this.label,
    this.value, {
    super.key,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Text(
            label,
            style: const TextStyle(
              color: C.tx3,
              fontSize: 10,
              letterSpacing: 0.8,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.bold,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }
}

class PanelLabel extends StatelessWidget {
  final String text;

  const PanelLabel(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: C.tx3,
        fontSize: 9,
        fontWeight: FontWeight.bold,
        letterSpacing: 1.8,
      ),
    );
  }
}
