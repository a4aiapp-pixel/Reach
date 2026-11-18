import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

enum GeoFieldType { country, city }

class GeoPlace {
  const GeoPlace(this.name, this.iso, this.context, this.searchKey);
  final String name;
  final String iso;
  final String context;
  final String searchKey;
}

/// Local, keyed and deduplicated open geographical data. This index never
/// obtains device coordinates, contacts external APIs, or charges per search.
class GeoDirectory {
  GeoDirectory._();
  static Future<void>? _loading;
  static final Map<String, String> _isoToCountry = {};
  static final Map<String, String> _countryToIso = {};
  static final Map<String, List<GeoPlace>> _citiesByIso = {};
  static final List<GeoPlace> _allCities = [];
  static final List<GeoPlace> _countries = [];
  static bool get ready => _countries.isNotEmpty && _allCities.isNotEmpty;

  static String simplify(String text) {
    var s = text.trim().toLowerCase();
    for (final pair in <(String, String)>[
      ('[àáâãäåāăą]', 'a'), ('[èéêëēęě]', 'e'),
      ('[ìíîïīı]', 'i'), ('[òóôõöøō]', 'o'),
      ('[ùúûüū]', 'u'), ('[çćč]', 'c'), ('[ñń]', 'n'),
      ('[śšș]', 's'), ('[ğģ]', 'g'), ('[żźž]', 'z'),
      ('[ł]', 'l'), ('[ýÿ]', 'y'), ('[ř]', 'r'),
    ]) {
      s = s.replaceAll(RegExp(pair.$1), pair.$2);
    }
    return s.replaceAll(RegExp(r'\s+'), ' ');
  }

  static Future<void> load() => _loading ??= _initialize();

  static Future<void> _initialize() async {
    final countries = await rootBundle.loadString('assets/geodata/countries.tsv');
    final cities = await rootBundle.loadString('assets/geodata/cities.tsv');
    for (final line in countries.split('\n')) {
      final v = line.split('\t');
      if (v.length < 2 || v[0].length != 2 || v[1].isEmpty) continue;
      final iso = v[0].toUpperCase();
      final name = v[1].trim();
      _isoToCountry[iso] = name;
      _countryToIso[simplify(name)] = iso;
      _countries.add(GeoPlace(name, iso, 'Country', simplify(name)));
    }
    const aliases = <String, String>{
      'usa': 'US', 'us': 'US', 'u.s.a.': 'US',
      'uk': 'GB', 'u.k.': 'GB', 'britain': 'GB',
      'uae': 'AE', 'u.a.e.': 'AE',
    };
    for (final entry in aliases.entries) {
      if (_isoToCountry.containsKey(entry.value)) {
        _countryToIso[entry.key] = entry.value;
      }
    }
    for (final line in cities.split('\n')) {
      final v = line.split('\t');
      if (v.length < 2) continue;
      final iso = v[0].toUpperCase();
      final country = _isoToCountry[iso];
      if (country == null || v[1].isEmpty) continue;
      final name = v[1].trim();
      final item = GeoPlace(name, iso, country, simplify(name));
      _allCities.add(item);
      _citiesByIso.putIfAbsent(iso, () => []).add(item);
    }
    _countries.sort((a, b) => a.name.compareTo(b.name));
    if (_countries.length < 230 || _allCities.length < 10000) {
      throw StateError('The bundled country/city directory is incomplete');
    }
  }

  static String? isoForCountry(String name) =>
      _countryToIso[simplify(name)] ??
      (_isoToCountry.containsKey(name.trim().toUpperCase())
          ? name.trim().toUpperCase() : null);

  static String? canonicalCountry(String input) {
    final iso = isoForCountry(input);
    return iso == null ? null : _isoToCountry[iso];
  }

  static List<GeoPlace> suggestCountries(String text, {int limit = 9}) {
    if (!ready) return const [];
    final q = simplify(text);
    if (q.isEmpty) {
      const frequent = <String>['PK', 'IN', 'US', 'GB', 'AE', 'CA', 'AU', 'SA'];
      return frequent.where(_isoToCountry.containsKey)
          .map((iso) => GeoPlace(_isoToCountry[iso]!, iso, 'Country',
              simplify(_isoToCountry[iso]!))).take(limit).toList();
    }
    final starts = <GeoPlace>[];
    final contains = <GeoPlace>[];
    for (final c in _countries) {
      if (c.searchKey.startsWith(q) || c.iso.toLowerCase().startsWith(q)) {
        if (starts.length < limit) starts.add(c);
      } else if (c.searchKey.contains(q) && contains.length < limit) {
        contains.add(c);
      }
    }
    return [...starts, ...contains].take(limit).toList();
  }

  static List<GeoPlace> suggestCities(String text, String country,
      {int limit = 9}) {
    if (!ready) return const [];
    final q = simplify(text);
    if (q.isEmpty) return const [];
    final iso = isoForCountry(country);
    final source = iso == null ? _allCities : (_citiesByIso[iso] ?? const <GeoPlace>[]);
    final starts = <GeoPlace>[];
    final contains = <GeoPlace>[];
    // Entries are sorted by population descending in the generated TSV.
    for (final c in source) {
      if (c.searchKey.startsWith(q)) {
        if (starts.length < limit) starts.add(c);
      } else if (c.searchKey.contains(q) && contains.length < limit) {
        contains.add(c);
      }
      if (starts.length >= limit) break;
    }
    return [...starts, ...contains].take(limit).toList();
  }
}

/// One reusable field for first-run setup and profile editing. Users may type
/// small towns missing from the curated open-data directory; selection never
/// accesses or infers their physical position.
class GeoAutocompleteField extends StatefulWidget {
  const GeoAutocompleteField({
    super.key, required this.controller, required this.type,
    this.countryController, this.clearCityOnCountryChange,
    this.required = false,
  });
  final TextEditingController controller;
  final GeoFieldType type;
  final TextEditingController? countryController;
  final TextEditingController? clearCityOnCountryChange;
  final bool required;

  @override
  State<GeoAutocompleteField> createState() => _GeoAutocompleteFieldState();
}

class _GeoAutocompleteFieldState extends State<GeoAutocompleteField> {
  final FocusNode _focusNode = FocusNode();
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    GeoDirectory.load().then((_) {
      if (mounted) setState(() => _loaded = true);
    }).catchError((Object _) {
      // Manual country/city typing remains available even if assets fail.
    });
    widget.countryController?.addListener(_countryChanged);
  }

  @override
  void didUpdateWidget(covariant GeoAutocompleteField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.countryController != widget.countryController) {
      oldWidget.countryController?.removeListener(_countryChanged);
      widget.countryController?.addListener(_countryChanged);
    }
  }

  void _countryChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.countryController?.removeListener(_countryChanged);
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RawAutocomplete<GeoPlace>(
    key: ValueKey(widget.type.name),
    textEditingController: widget.controller,
    focusNode: _focusNode,
    displayStringForOption: (p) => p.name,
    optionsBuilder: (v) {
      if (!_loaded) return const <GeoPlace>[];
      return widget.type == GeoFieldType.country
          ? GeoDirectory.suggestCountries(v.text)
          : GeoDirectory.suggestCities(
              v.text, widget.countryController?.text ?? '');
    },
    onSelected: (option) {
      if (widget.type == GeoFieldType.country) {
        widget.clearCityOnCountryChange?.clear();
      }
    },
    fieldViewBuilder: (context, controller, focus, onSubmit) => TextField(
      controller: controller,
      focusNode: focus,
      maxLength: 100,
      textCapitalization: TextCapitalization.words,
      onSubmitted: (_) => onSubmit(),
      onChanged: (_) {
        if (widget.type == GeoFieldType.country) {
          widget.clearCityOnCountryChange?.clear();
        }
      },
      decoration: InputDecoration(
        labelText: widget.type == GeoFieldType.country
            ? 'Country${widget.required ? ' *' : ''}'
            : 'City / town${widget.required ? ' *' : ''}',
        hintText: widget.type == GeoFieldType.country
            ? 'Start typing a country'
            : 'Search cities or enter a smaller town',
        helperText: widget.type == GeoFieldType.country
            ? 'Select a suggested country for accurate matching'
            : 'Suggestions follow the selected country. Custom towns allowed.',
        prefixIcon: Icon(widget.type == GeoFieldType.country
            ? Icons.public_outlined : Icons.location_city_outlined),
        suffixIcon: Icon(_loaded
            ? Icons.keyboard_arrow_down_rounded : Icons.hourglass_empty_rounded),
      ),
    ),
    optionsViewBuilder: (context, select, options) {
      final list = options.toList();
      return Align(
        alignment: Alignment.topLeft,
        child: Material(
          elevation: 10,
          clipBehavior: Clip.antiAlias,
          borderRadius: BorderRadius.circular(14),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: 260,
              maxWidth: MediaQuery.sizeOf(context).width - 32,
            ),
            child: ListView.builder(
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              itemCount: list.length,
              itemBuilder: (context, i) {
                final item = list[i];
                return ListTile(
                  dense: true,
                  leading: Icon(widget.type == GeoFieldType.country
                      ? Icons.flag_outlined : Icons.location_on_outlined),
                  title: Text(item.name, maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  subtitle: Text(item.context, maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  onTap: () => select(item),
                );
              },
            ),
          ),
        ),
      );
    },
  );
}
