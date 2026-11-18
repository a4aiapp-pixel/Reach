# Reach country and city search — open data credits

Reach's offline place suggestion directory is generated at build time by `tools/generate_geo_assets.py`. It embeds a **curated subset** of countries and city/town names with a population threshold of 5,000. This is not a definitive list of all settlements and must not be represented as such. The app permits manual entry of additional places, without requiring GPS.

**Underlying geographic data:** © GeoNames contributors, https://www.geonames.org/ . Licensed under [Creative Commons Attribution 4.0 International (CC BY 4.0)](https://creativecommons.org/licenses/by/4.0/). Attribution provided as requested by the GeoNames terms at https://www.geonames.org/export/.

**Data preparation package:** `geonamescache==3.0.2`, © Ramiro Gómez and contributors, MIT License, https://github.com/yaph/geonamescache . Used to produce a compressed-in-purpose, simplified country/city directory. No geonamescache executable code is embedded in the Android app.

**Modifications:** Original geographic records are filtered by population, converted into `countries.tsv` and `cities.tsv`, duplicate city names within countries are collapsed, sorted for responsive lookup, and stripped of coordinates and unrelated personal/location fields. These modifications are not endorsed by GeoNames.

**Runtime privacy:** Searches are performed fully on device, with no external geocoding API, no per-query billing, and no transfer of typed location terms to the data provider. The optional independent 'near me' feature requests coarse Android location only after specific user consent and rounds coordinates before uploading approximate data to Reach.

**Limitations:** Country and city names may change, and small rural settlements or locally preferred spellings may not be included. The directory is provided without warranty. Refresh to a later GeoNames dataset only after reviewing its license and testing.

[GeoNames export and attribution](https://www.geonames.org/export/) · [License terms](https://creativecommons.org/licenses/by/4.0/).
