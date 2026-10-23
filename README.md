# reguard-filters

Safari content blocker rules for the reguard app, rebuilt every day from public filter lists.

| Blocker | Lists |
|---|---|
| `ads` | AdGuard Base (includes EasyList), AdGuard Russian, AdGuard Mobile Ads |
| `annoyances` | AdGuard Cookie Notices, Popups, Mobile App Banners, Other Annoyances, Widgets |

The iOS-optimized versions of the lists are converted with AdGuard's [SafariConverterLib](https://github.com/AdguardTeam/SafariConverterLib) (version pinned in `filters.json`) for three Safari feature levels: 15, 16.4 and 26.

## Output

The [`latest` release](../../releases/tag/latest) holds:

- `manifest.json`: when the rules were built, list versions, and for each file its blocker, Safari version, rule count and the SHA-256 of the uncompressed JSON;
- `<blocker>-<safari>.json.deflate`: the rule JSON compressed with raw DEFLATE (`COMPRESSION_ZLIB` in Apple's Compression framework).

A build that downloads a broken list, produces too few rules, exceeds Safari's 150,000-rule limit, or produces rules WebKit refuses to compile (`verify.swift`) fails without publishing.

## Building locally

```sh
python3 build.py converter   # needs Swift
python3 build.py rules       # writes dist/
swift verify.swift dist      # compiles each file with WebKit
```

## Licenses

The rules are derived from [AdGuard filters](https://github.com/AdguardTeam/AdguardFilters) (GPL-3.0), which in turn include [EasyList](https://easylist.to). Credit for the lists goes to their authors.
