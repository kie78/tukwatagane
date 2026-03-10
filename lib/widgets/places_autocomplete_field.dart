import 'dart:async';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../core/app_config.dart';

class _PlacePrediction {
  final String description;
  final String placeId;
  _PlacePrediction({required this.description, required this.placeId});
}

/// A [TextField] that queries the Google Places Autocomplete API as the user
/// types and displays matching suggestions in an overlay dropdown.
///
/// When [resolveLabel] is provided, the selected place's coordinates are
/// fetched via the Places Details API and passed to the callback; the
/// returned string (e.g. a campus zone name) is what gets stored in the
/// controller instead of the raw place description.
class PlacesAutocompleteField extends StatefulWidget {
  final TextEditingController controller;
  final InputDecoration decoration;
  final bool enabled;

  /// Optional. Called with (lat, lng, description) after the user picks a
  /// suggestion. Return the label you want written into the controller, or
  /// null to fall back to the raw place description.
  final String? Function(double lat, double lng, String description)? resolveLabel;

  /// Optional. Called with the resolved (lat, lng) after the Places Details
  /// API call succeeds. Use this to capture coordinates for storage.
  final void Function(double lat, double lng)? onLocationResolved;

  const PlacesAutocompleteField({
    super.key,
    required this.controller,
    required this.decoration,
    this.enabled = true,
    this.resolveLabel,
    this.onLocationResolved,
  });

  @override
  State<PlacesAutocompleteField> createState() =>
      _PlacesAutocompleteFieldState();
}

class _PlacesAutocompleteFieldState extends State<PlacesAutocompleteField> {
  final _dio = Dio();
  final _layerLink = LayerLink();
  final _focusNode = FocusNode();
  OverlayEntry? _overlayEntry;
  List<_PlacePrediction> _suggestions = [];
  bool _resolving = false;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      if (!_focusNode.hasFocus) _removeSuggestions();
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _focusNode.dispose();
    _removeSuggestions();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    if (value.trim().isEmpty) {
      _removeSuggestions();
      return;
    }
    _debounce = Timer(
      const Duration(milliseconds: 350),
      () => _fetchSuggestions(value.trim()),
    );
  }

  Future<void> _fetchSuggestions(String input) async {
    try {
      final resp = await _dio.get(
        'https://maps.googleapis.com/maps/api/place/autocomplete/json',
        queryParameters: {
          'input': input,
          'key': AppConfig.mapsApiKey,
          'types': 'geocode',
        },
      );
      if (!mounted) return;
      final predictions = (resp.data['predictions'] as List?) ?? [];
      final suggestions = predictions
          .map((p) => _PlacePrediction(
                description: p['description'] as String,
                placeId: p['place_id'] as String,
              ))
          .toList();
      _showSuggestions(suggestions);
    } catch (_) {
      _removeSuggestions();
    }
  }

  void _showSuggestions(List<_PlacePrediction> suggestions) {
    _removeSuggestions();
    if (suggestions.isEmpty || !mounted) return;
    _suggestions = suggestions;
    _overlayEntry = _buildOverlayEntry();
    Overlay.of(context).insert(_overlayEntry!);
  }

  void _removeSuggestions() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    _suggestions = [];
  }

  Future<void> _selectSuggestion(_PlacePrediction prediction) async {
    _removeSuggestions();
    _focusNode.unfocus();

    if (widget.resolveLabel == null) {
      _setControllerText(prediction.description);
      return;
    }

    // Show the description immediately so the field isn't empty while we resolve.
    _setControllerText(prediction.description);
    if (mounted) setState(() => _resolving = true);

    try {
      final resp = await _dio.get(
        'https://maps.googleapis.com/maps/api/place/details/json',
        queryParameters: {
          'place_id': prediction.placeId,
          'fields': 'geometry',
          'key': AppConfig.mapsApiKey,
        },
      );
      if (!mounted) return;
      final loc = resp.data['result']?['geometry']?['location'];
      if (loc != null) {
        final lat = (loc['lat'] as num).toDouble();
        final lng = (loc['lng'] as num).toDouble();
        widget.onLocationResolved?.call(lat, lng);
        final label = widget.resolveLabel!(lat, lng, prediction.description);
        if (label != null) _setControllerText(label);
      }
    } catch (_) {
      // Keep the raw description already set above.
    } finally {
      if (mounted) setState(() => _resolving = false);
    }
  }

  void _setControllerText(String text) {
    widget.controller.text = text;
    widget.controller.selection =
        TextSelection.fromPosition(TextPosition(offset: text.length));
  }

  OverlayEntry _buildOverlayEntry() {
    final renderBox = context.findRenderObject() as RenderBox;
    final size = renderBox.size;
    return OverlayEntry(
      builder: (ctx) => Positioned(
        width: size.width,
        child: CompositedTransformFollower(
          link: _layerLink,
          showWhenUnlinked: false,
          offset: Offset(0, size.height + 4),
          child: Material(
            elevation: 6,
            borderRadius: BorderRadius.circular(12),
            clipBehavior: Clip.antiAlias,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 220),
              child: ListView.separated(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: _suggestions.length,
                separatorBuilder: (_, __) =>
                    const Divider(height: 1, indent: 44),
                itemBuilder: (_, index) => ListTile(
                  dense: true,
                  leading: const Icon(
                    Icons.location_on_outlined,
                    size: 18,
                    color: Colors.grey,
                  ),
                  title: Text(
                    _suggestions[index].description,
                    style: const TextStyle(fontSize: 13),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  onTap: () => _selectSuggestion(_suggestions[index]),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: TextField(
        controller: widget.controller,
        focusNode: _focusNode,
        enabled: widget.enabled && !_resolving,
        onChanged: _onChanged,
        decoration: widget.decoration.copyWith(
          suffixIcon: _resolving
              ? const Padding(
                  padding: EdgeInsets.all(12),
                  child: SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : widget.decoration.suffixIcon,
        ),
      ),
    );
  }
}
