import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:country_picker/country_picker.dart';

/// Searchable country selector and network-backed city suggestions.
/// Geocoding is optional: manual entry remains possible when offline.
class ReachCountryField extends StatelessWidget {
  const ReachCountryField({super.key, required this.controller});
  final TextEditingController controller;
  @override
  Widget build(BuildContext context) => TextField(
    controller: controller, readOnly: true,
    onTap: () => showCountryPicker(
      context: context, showPhoneCode: true,
      onSelect: (country) => controller.text = country.name,
    ),
    decoration: const InputDecoration(
      labelText: 'Country *', helperText: 'Tap to search and select your country',
      suffixIcon: Icon(Icons.arrow_drop_down),
    ),
  );
}

class ReachCityField extends StatefulWidget {
  const ReachCityField({super.key, required this.controller, required this.country});
  final TextEditingController controller;
  final TextEditingController country;
  @override State<ReachCityField> createState() => _ReachCityFieldState();
}

class _ReachCityFieldState extends State<ReachCityField> {
  Timer? _timer;
  int _request = 0;
  List<String> _matches = [];
  bool _loading = false;
  @override void initState() {
    super.initState();
    widget.controller.addListener(_schedule);
    widget.country.addListener(_countryChanged);
  }
  void _countryChanged() {
    _request++;
    if (mounted) setState(() => _matches = []);
  }
  void _schedule() {
    _timer?.cancel();
    final query = widget.controller.text.trim();
    if (query.length < 2) {
      _request++;
      if (mounted) setState(() { _matches = []; _loading = false; });
      return;
    }
    _timer = Timer(const Duration(milliseconds: 350), () => _lookup(query));
  }
  Future<void> _lookup(String query) async {
    final id = ++_request;
    if (mounted) setState(() => _loading = true);
    try {
      final uri = Uri.https('geocoding-api.open-meteo.com', '/v1/search', {
        'name': query, 'count': '20', 'language': 'en', 'format': 'json',
      });
      final response = await http.get(uri).timeout(const Duration(seconds: 6));
      if (response.statusCode != 200) throw StateError('Lookup unavailable');
      final results = (jsonDecode(response.body) as Map)['results'] as List? ?? [];
      final selected = widget.country.text.trim().toLowerCase();
      final cities = results.where((item) {
        if (item is! Map) return false;
        return selected.isEmpty ||
          (item['country']?.toString().toLowerCase() == selected);
      }).map((item) => (item as Map)['name']?.toString() ?? '')
        .where((name) => name.isNotEmpty).toSet().take(8).toList();
      if (mounted && id == _request) setState(() => _matches = cities);
    } catch (_) {
      if (mounted && id == _request) setState(() => _matches = []);
    } finally {
      if (mounted && id == _request) setState(() => _loading = false);
    }
  }
  @override void dispose() {
    _timer?.cancel();
    widget.controller.removeListener(_schedule);
    widget.country.removeListener(_countryChanged);
    super.dispose();
  }
  @override Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      TextField(
        controller: widget.controller,
        textCapitalization: TextCapitalization.words,
        decoration: InputDecoration(
          labelText: 'City *',
          hintText: 'Start typing your city',
          helperText: 'Suggestions appear as you type; manual entry is allowed',
          suffixIcon: _loading ? const Padding(
            padding: EdgeInsets.all(14),
            child: SizedBox(width: 16, height: 16,
              child: CircularProgressIndicator(strokeWidth: 2)),
          ) : const Icon(Icons.location_city_outlined),
        ),
      ),
      if (_matches.isNotEmpty)
        ..._matches.map((city) => ListTile(
          dense: true, title: Text(city),
          leading: const Icon(Icons.place_outlined, size: 19),
          onTap: () {
            _timer?.cancel();
            _request++;
            widget.controller.text = city;
            FocusScope.of(context).unfocus();
            setState(() => _matches = []);
          },
        )),
    ],
  );
}
