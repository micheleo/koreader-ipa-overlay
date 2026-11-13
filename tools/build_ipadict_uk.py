"""Convert ipa-dict en_UK.txt into a compact "word<TAB>ipa" file for the plugin.

ipa-dict en_UK (GPL-3.0, from ipacards) writes the stress mark after the first onset consonant
(tˈiːtʃəz). This script moves it to the syllable start (ˈtiːtʃəz) with the same onset rule
as phonology.lua. Only the first pronunciation of each word is kept.
"""
import re
import sys

MULTI = ["tʃ", "dʒ", "aɪ", "aʊ", "ɔɪ", "eɪ", "əʊ", "ɪə", "eə", "ʊə", "iː", "uː", "ɔː", "ɑː", "ɜː", "aː", "oː"]
VOWEL_CHARS = set("aeiouɪʊəɐɒɔɑɜæʌɛɵ")
MARKS = ("ˈ", "ˌ")
STOPS_FRICATIVES = set("pbtdkɡfv")
LIQUIDS_GLIDES = set(["l", "ɹ", "r", "w", "j"])


def tokenize(ipa):
    tokens, index = [], 0
    while index < len(ipa):
        for multi in MULTI:
            if ipa.startswith(multi, index):
                tokens.append(multi)
                index += len(multi)
                break
        else:
            tokens.append(ipa[index])
            index += 1
    return tokens


def is_vowel(token):
    return token[0] in VOWEL_CHARS


def can_extend_onset(previous, current):
    if previous == "s":
        return current != "s"
    return previous in STOPS_FRICATIVES and current in LIQUIDS_GLIDES


def move_marks_to_syllable_start(ipa):
    tokens = tokenize(ipa.replace("g", "ɡ"))
    result = []
    for token in tokens:
        if token in MARKS:
            result.append(token)
            continue
        if result and result[-1] in MARKS and is_vowel(token):
            mark = result.pop()
            start = len(result)
            while start > 0 and result[start - 1] not in MARKS and not is_vowel(result[start - 1]):
                first = result[start] if start < len(result) else token
                if start == len(result) or can_extend_onset(result[start - 1], first):
                    start -= 1
                else:
                    break
            result.insert(start, mark)
        result.append(token)
    return "".join(result)


if __name__ == "__main__":
    source, target = sys.argv[1], sys.argv[2]
    count = 0
    with open(source, encoding="utf-8") as src, open(target, "w", encoding="utf-8") as out:
        for line in src:
            word, _, pronunciations = line.rstrip("\n").partition("\t")
            if not re.fullmatch(r"[a-z']+", word) or not pronunciations:
                continue
            first = pronunciations.split(",")[0].strip().strip("/")
            if first:
                out.write(f"{word}\t{move_marks_to_syllable_start(first)}\n")
                count += 1
    print(count, "words")
