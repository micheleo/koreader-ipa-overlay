# Changelog

## 0.1.0 (2026-11-13)

- IPA overlay above every word, per book toggle, size, color and language options.
- English US (CMUdict), English UK (ipa-dict en_UK, GPL-3.0 data) and rule based Italian.
- Dictionaries are downloaded on first use, SHA256 verified, nothing is bundled.
- No stress mark on words with a single vowel.
- Overlay turns itself off if painting fails.
- Italian: `c'è`, `c'era` keep the `c` sound, -abile, -ibile and -evole words get the right stress.
- English: possessives missing from the dictionary (`Alice's`) get the possessive sound.
- Download: removed the redundant size check, logs how long each file took.
- Tests for the apostrophe merge with a fake document.
- Italian `abile` (whole word suffix) stressed on the first syllable.
- Menu item to delete the downloaded dictionaries.
