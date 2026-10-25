# reguard-filters

Safari content blocker rules for the reguard app, rebuilt every day from community filter lists.

The app's [privacy policy](docs/privacy-policy.md) and [support page](docs/support.md) live here too.

| Blocker | List | Authors | License |
|---|---|---|---|
| `ads` | [EasyList](https://easylist.to/) | The EasyList authors | [CC BY-SA 3.0](https://creativecommons.org/licenses/by-sa/3.0/) (EasyList is dual-licensed; this project uses it under CC BY-SA 3.0) |
| `annoyances` | [Fanboy's Annoyance List](https://easylist.to/) (includes the EasyList Cookie List and Fanboy's Social, Notifications and Mobile Notifications lists) | The EasyList authors | [CC BY 3.0](https://creativecommons.org/licenses/by/3.0/) |

The lists are converted with AdGuard's [SafariConverterLib](https://github.com/AdguardTeam/SafariConverterLib) (version pinned in `filters.json`) for three Safari feature levels: 15, 16.4 and 26.

## Output

The [`latest` release](../../releases/tag/latest) holds:

- `manifest.json`: when the rules were built, the lists they came from with their authors and licenses, and for each file its blocker, Safari version, rule count and the SHA-256 of the uncompressed JSON;
- `<blocker>-<safari>.json.deflate`: the rule JSON compressed with raw DEFLATE (`COMPRESSION_ZLIB` in Apple's Compression framework).

Hiding selectors WebKit can't parse (extended syntax such as `:remove-class()` or `:matches-path()`) are dropped one by one (`selectors.swift`): left in, a single one makes Safari drop the whole rule it sits in, with every other selector in it.

A build that downloads a broken list, produces too few rules, exceeds Safari's 150,000-rule limit (less the one rule the app adds), produces a kind of rule the app doesn't install (redirects, header changes), or produces rules WebKit refuses to compile (`verify.swift`) fails without publishing.

## Building locally

```sh
python3 build.py converter   # needs Swift
python3 build.py rules       # writes dist/ (needs Swift and WebKit, so macOS)
swift verify.swift dist      # compiles each file with WebKit
```

## Licenses

The published rule files are adaptations of the lists above: the same rules, converted to Safari's content blocker format. The `ads` files are licensed under [CC BY-SA 3.0](https://creativecommons.org/licenses/by-sa/3.0/) and the `annoyances` files under [CC BY 3.0](https://creativecommons.org/licenses/by/3.0/), with credit to the EasyList authors (https://easylist.to/). The converter only runs in this repository's build; it is not part of the published files.
