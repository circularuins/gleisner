import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';

import '../../l10n/l10n.dart';
import '../../theme/gleisner_tokens.dart';
import '../../utils/color_hex.dart';
import '../../utils/ime_safe_focus.dart';

/// Color picker that combines a 10-swatch preset grid with an optional
/// "More colors" expansion that surfaces an HSV wheel + a HEX text input.
///
/// All color exchange happens via `#RRGGBB` 6-digit HEX strings to match
/// the backend Track.color contract (`varchar(7)`,
/// `/^#[0-9A-Fa-f]{6}$/`). Alpha is intentionally stripped — see
/// `lib/utils/color_hex.dart`.
///
/// State (TextEditingController / FocusNode) is owned by the picker
/// itself in `initState` / `dispose`, per
/// `.claude/rules/frontend-implementation.md`
/// "build() 内でリソースオブジェクトを生成しない".
class TrackColorPicker extends StatefulWidget {
  /// Currently selected color as a `#RRGGBB` HEX string. The picker
  /// highlights this in the preset grid and uses it as the initial
  /// position of the HSV wheel and the HEX text field.
  final String selectedHex;

  /// Called whenever the user picks a different color. Always invoked
  /// with a valid `#RRGGBB` value (uppercase, alpha stripped). The
  /// parent is responsible for storing this and re-rendering the
  /// picker with the new [selectedHex].
  final ValueChanged<String> onChanged;

  const TrackColorPicker({
    super.key,
    required this.selectedHex,
    required this.onChanged,
  });

  @override
  State<TrackColorPicker> createState() => _TrackColorPickerState();
}

class _TrackColorPickerState extends State<TrackColorPicker> {
  bool _showCustom = false;
  late Color _customColor;
  late final TextEditingController _hexController;
  late final FocusNode _hexFocusNode;

  @override
  void initState() {
    super.initState();
    _customColor = hex6ToColor(widget.selectedHex) ?? colorTrackFallback;
    _hexController = TextEditingController(
      text: widget.selectedHex.toUpperCase(),
    );
    _hexFocusNode = createImeSafeFocusNode(_hexController);
  }

  @override
  void didUpdateWidget(TrackColorPicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    // When the parent forces a new selection (e.g. user tapped a preset),
    // sync the wheel + text field so re-opening "More colors" starts
    // from the latest pick.
    if (widget.selectedHex != oldWidget.selectedHex) {
      final parsed = hex6ToColor(widget.selectedHex);
      if (parsed != null) _customColor = parsed;
      final upper = widget.selectedHex.toUpperCase();
      if (_hexController.text != upper) {
        _hexController.text = upper;
      }
    }
  }

  @override
  void dispose() {
    // FocusNode must be disposed before the controller (the IME-safe
    // focus node holds a reference to the controller — see
    // `lib/utils/ime_safe_focus.dart`).
    _hexFocusNode.dispose();
    _hexController.dispose();
    super.dispose();
  }

  void _onPresetTap(String hex) {
    final upper = hex.toUpperCase();
    setState(() {
      final parsed = hex6ToColor(upper);
      if (parsed != null) _customColor = parsed;
      if (_hexController.text != upper) _hexController.text = upper;
    });
    widget.onChanged(upper);
  }

  void _onWheelColorChanged(Color color) {
    final hex = colorToHex6(color);
    setState(() {
      _customColor = color;
      if (_hexController.text != hex) _hexController.text = hex;
    });
    widget.onChanged(hex);
  }

  void _onHexFieldChanged(String raw) {
    var value = raw.trim().toUpperCase();
    if (value.isNotEmpty && !value.startsWith('#')) {
      value = '#$value';
    }
    if (!isValidHex6(value)) {
      // Don't propagate invalid input upstream; the validator decoration
      // surfaces the error via the field's helperText/errorText below.
      setState(() {});
      return;
    }
    final parsed = hex6ToColor(value);
    if (parsed == null) return;
    setState(() => _customColor = parsed);
    widget.onChanged(value);
  }

  String? _hexFieldError(AppLocalizations l10n) {
    final raw = _hexController.text.trim();
    if (raw.isEmpty) return null;
    var value = raw.toUpperCase();
    if (!value.startsWith('#')) value = '#$value';
    return isValidHex6(value) ? null : l10n.invalidHexFormat;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final selected = widget.selectedHex.toLowerCase();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(l10n.selectColor, style: Theme.of(context).textTheme.labelMedium),
        const SizedBox(height: spaceSm),
        Wrap(
          spacing: spaceXs,
          runSpacing: spaceXs,
          children: [
            for (final preset in trackColorPresets)
              _PresetSwatch(
                hex: preset,
                isSelected: preset.toLowerCase() == selected,
                onTap: () => _onPresetTap(preset),
                semanticsLabel: l10n.colorPresetLabel(preset),
              ),
          ],
        ),
        const SizedBox(height: spaceSm),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => setState(() => _showCustom = !_showCustom),
            icon: Icon(_showCustom ? Icons.expand_less : Icons.expand_more),
            label: Text(l10n.moreColors),
          ),
        ),
        if (_showCustom) ...[
          ColorPicker(
            pickerColor: _customColor,
            onColorChanged: _onWheelColorChanged,
            enableAlpha: false,
            displayThumbColor: true,
            paletteType: PaletteType.hueWheel,
            labelTypes: const [],
            pickerAreaBorderRadius: BorderRadius.circular(radiusMd),
          ),
          const SizedBox(height: spaceSm),
          TextField(
            controller: _hexController,
            focusNode: _hexFocusNode,
            decoration: InputDecoration(
              labelText: l10n.customColorHex,
              hintText: '#RRGGBB',
              border: const OutlineInputBorder(),
              errorText: _hexFieldError(l10n),
            ),
            maxLength: 7,
            textCapitalization: TextCapitalization.characters,
            onChanged: _onHexFieldChanged,
          ),
        ],
      ],
    );
  }
}

class _PresetSwatch extends StatelessWidget {
  final String hex;
  final bool isSelected;
  final VoidCallback onTap;
  final String semanticsLabel;

  const _PresetSwatch({
    required this.hex,
    required this.isSelected,
    required this.onTap,
    required this.semanticsLabel,
  });

  @override
  Widget build(BuildContext context) {
    final color = hex6ToColor(hex) ?? colorTrackFallback;
    return Semantics(
      label: semanticsLabel,
      button: true,
      selected: isSelected,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        // 44x44 logical px meets the Material minimum tap target while
        // keeping the visible swatch a calmer 32x32 dot. The check icon
        // doubles as a non-color cue for color-vision-deficient users
        // (PR #346 review F5).
        child: SizedBox(
          width: 44,
          height: 44,
          child: Center(
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: isSelected
                        ? Border.all(color: colorAccentGold, width: 2)
                        : null,
                  ),
                ),
                if (isSelected)
                  const Icon(Icons.check, size: 16, color: Colors.white),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
