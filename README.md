# IPA pronunciation for KOReader

Shows the IPA pronunciation above every word of an English or Italian EPUB, with a per-book toggle.

## How it works

An overlay draws the IPA above each word of the current page when the page is painted. The book is never modified,
so selection, highlights, dictionary and translation keep working on the original text.

- crengine returns one box per line for a text range, so the plugin queries every word on its own and caches the result per page.
- Line spacing is computed from the IPA size when the overlay is turned on, and reset to 100% when it is turned off.
- English US: CMUdict (ARPAbet converted to IPA on the device).
- English UK: ipa-dict `en_UK` (GPL-3.0 data derived from ipacards, see NOTICE; stress mark moved to the syllable start on the device), words missing there use CMUdict with UK vowels and r-dropping.
- Italian: rule based. Stress comes from the written accent, otherwise penultimate syllable. Open and closed e/o are not marked. `z` is `ts`, long between vowels before i + vowel and in `zz`, never `dz`. Words not stressed on the penultimate syllable and written without an accent (tavolo, aquila) get the wrong stress.
- Languages are entries of `engines.lua`: id, label, ISO codes for auto detection, needed files, `create`.
- Select a word and tap "Pronunciation" in the popup to see its IPA, also when the overlay is off.

## Install

Copy the `ipaoverlay.koplugin` folder to the `koreader/plugins/` folder of the device (Kindle, Kobo, ...), for example by USB, then restart KOReader.
On macOS skip the `._*` files: `rsync -rt --delete --exclude '._*' ipaoverlay.koplugin/ <device>/koreader/plugins/ipaoverlay.koplugin/`

Dictionaries are not part of the plugin. The first time an English engine is needed the plugin asks to download them (about 5 MB, WiFi)
from the pinned upstream repositories into the `ipaoverlay/` folder of the KOReader data directory (`koreader/ipaoverlay/` on Kindle). Italian needs no download.
Measured on x86: loading both English dictionaries takes 0.17 s and about 25 MB of Lua memory, expect slower on e-readers.

Menu: Tools tab, "IPA pronunciation". Options: size, color, language (Automatic, English US, English UK, Italian).
It can also be bound to a gesture (action "Toggle IPA pronunciation").

## Development

    make test    # luajit tests in Docker
    make lint    # luacheck and ruff in Docker

`tools/build_ipadict_uk.py` is the reference for `uk_stress.lua`. `tests/uk_stress_fixtures.lua` holds its outputs, regenerate them if the rule changes.

## Known limits

No audio. Italian open and closed e/o are not marked, `z` is `ts`, long between vowels before i + vowel and in `zz`, never `dz`. Words not stressed on the penultimate syllable and written without an accent (tavolo, aquila) get the wrong stress. UK fallback for words missing in ipa-dict is approximate.
Tested only on a Kindle Paperwhite 11th gen (minimum KOReader version not checked yet).

## Fonts

No font is shipped. The IPA is drawn with KOReader's bundled Noto Sans, with KOReader's own fallback fonts for missing glyphs.

## License

AGPL-3.0-or-later, see LICENSE. Dictionary data has its own licenses, see NOTICE.
