#!/usr/bin/env python3
"""Build a compact, reproducible offline country/city directory for Reach.

Source: GeoNames (https://www.geonames.org), CC BY 4.0.
Redistribution via geonamescache 3.0.2, MIT-licensed Python package.
This is a curated population-based subset, not every hamlet on Earth.
For smaller villages and neighborhoods the app permits free-form city entry.
No API key, location access, network request or recurring service cost at runtime.
"""
from pathlib import Path
import geonamescache

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "assets" / "geodata"
OUT.mkdir(parents=True, exist_ok=True)

gc = geonamescache.GeonamesCache(min_city_population=5000)
raw_countries = gc.get_countries()
raw_cities = gc.get_cities()
countries = {}
for record in raw_countries.values():
    iso = str(record.get("iso", "")).strip().upper()
    name = str(record.get("name", "")).replace("\t", " ").strip()
    if len(iso) == 2 and name:
        countries[iso] = name

(OUT / "countries.tsv").write_text(
    "".join(f"{code}\t{name}\n" for code, name in
            sorted(countries.items(), key=lambda p: p[1].casefold())),
    encoding="utf-8"
)

cities = {}
for record in raw_cities.values():
    code = str(record.get("countrycode", "")).strip().upper()
    name = str(record.get("name", "")).replace("\t", " ").replace("\n", " ").strip()
    if code not in countries or not (1 <= len(name) <= 100):
        continue
    population = max(0, int(record.get("population") or 0))
    key = (code, name.casefold())
    existing = cities.get(key)
    if existing is None or population > existing[0]:
        cities[key] = (population, name)

rows = [(code, name, pop) for (code, _), (pop, name) in cities.items()]
rows.sort(key=lambda p: (-p[2], p[1].casefold(), p[0]))
(OUT / "cities.tsv").write_text(
    "".join(f"{code}\t{name}\t{pop}\n" for code, name, pop in rows),
    encoding="utf-8"
)

if len(countries) < 230 or len(rows) < 10000:
    raise RuntimeError(f"Unexpected GeoNames dataset: {len(countries)} countries, {len(rows)} cities")
if not any(code == "PK" and name.casefold() == "lahore" for code, name, _ in rows):
    raise RuntimeError("GeoNames did not contain Lahore, Pakistan")
print(f"Created offline suggestions: {len(countries)} countries / {len(rows)} major cities.")
