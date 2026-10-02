import 'package:flutter/material.dart';

Widget appTextField(
  TextEditingController controller,
  String label, {
  bool required = false,
  TextInputType? type,
  int maxLines = 1,
  String? helper,
  String? Function(String?)? validator,
  bool obscure = false,
}) =>
    Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextFormField(
        controller: controller,
        keyboardType: type,
        maxLines: maxLines,
        obscureText: obscure,
        decoration: InputDecoration(labelText: required ? '$label *' : label, helperText: helper),
        validator: validator ?? (required ? (v) => (v == null || v.trim().isEmpty) ? 'Campo obligatorio' : null : null),
      ),
    );

Widget appNumberField(TextEditingController controller, String label, {bool required = false, bool decimal = true, String? helper}) => appTextField(
      controller,
      label,
      required: required,
      type: TextInputType.numberWithOptions(decimal: decimal),
      helper: helper,
      validator: (v) {
        final text = (v ?? '').trim();
        if (text.isEmpty) return required ? 'Campo obligatorio' : null;
        return num.tryParse(text.replaceAll(',', '.')) == null ? 'Ingresa un número válido' : null;
      },
    );

Widget appDropdown<T>(String label, T? value, Map<T, String> options, ValueChanged<T?> onChanged, {bool required = false}) => Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: DropdownButtonFormField<T>(
        isExpanded: true,
        initialValue: options.containsKey(value) ? value : null,
        decoration: InputDecoration(labelText: required ? '$label *' : label),
        items: [for (final e in options.entries) DropdownMenuItem(value: e.key, child: Text(e.value, overflow: TextOverflow.ellipsis))],
        onChanged: onChanged,
        validator: required ? (v) => v == null ? 'Selecciona una opción' : null : null,
      ),
    );

Widget submitButton(String label, bool busy, VoidCallback onPressed) => FilledButton(
      onPressed: busy ? null : onPressed,
      child: busy ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2)) : Text(label),
    );

Widget errorLine(BuildContext context, String? error) =>
    error == null ? const SizedBox.shrink() : Padding(padding: const EdgeInsets.only(bottom: 12), child: Text(error, style: TextStyle(color: Theme.of(context).colorScheme.error)));

String isoDate(DateTime d) => '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

String apiDateTime(DateTime d) => '${isoDate(d)} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}:00';

String shortDateTime(DateTime d) => '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

/// Fecha y hora en dos pasos.
Future<DateTime?> pickDateTime(BuildContext context, {DateTime? initial, DateTime? first, DateTime? last}) async {
  final now = DateTime.now();
  final date = await showDatePicker(
    context: context,
    initialDate: initial ?? now,
    firstDate: first ?? now.subtract(const Duration(days: 1)),
    lastDate: last ?? now.add(const Duration(days: 730)),
  );
  if (date == null || !context.mounted) return null;
  final time = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(initial ?? now));
  if (time == null) return null;
  return DateTime(date.year, date.month, date.day, time.hour, time.minute);
}
