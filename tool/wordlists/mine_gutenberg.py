"""Builds word lists from public-domain Project Gutenberg texts.

common_words.txt  most frequent everyday English words (from classic novels)
radio_candidates.txt  words over-represented in early radio/telegraph books,
                      reviewed by hand before going into radio_words.txt

Usage: python3 tool/wordlists/mine_gutenberg.py [cache_dir]
"""
import collections
import math
import os
import re
import sys
import urllib.request

HERE = os.path.dirname(os.path.abspath(__file__))
CACHE = sys.argv[1] if len(sys.argv) > 1 else os.path.join(HERE, '.cache')

# All public domain in the US (published before 1930).
GENERAL = [1342, 74, 1661, 98, 84, 76, 1400, 345]
RADIO = [6934, 63345, 66702, 38526, 27455, 25858, 25753, 22079]


def fetch(book_id):
    os.makedirs(CACHE, exist_ok=True)
    path = os.path.join(CACHE, f'pg{book_id}.txt')
    if not os.path.exists(path):
        url = f'https://www.gutenberg.org/cache/epub/{book_id}/pg{book_id}.txt'
        urllib.request.urlretrieve(url, path)
    text = open(path, encoding='utf-8', errors='ignore').read()
    # Drop the Project Gutenberg header and licence footer.
    start = re.search(r'\*\*\* ?START OF (THE|THIS) PROJECT GUTENBERG.*?\*\*\*', text)
    end = re.search(r'\*\*\* ?END OF (THE|THIS) PROJECT GUTENBERG', text)
    return text[start.end() if start else 0:end.start() if end else len(text)]


def count(ids):
    lower = collections.Counter()
    capital = collections.Counter()
    for i in ids:
        for w in re.findall(r"[A-Za-z]+", fetch(i)):
            (capital if w[0].isupper() else lower)[w.lower()] += 1
    return lower, capital


def usable(word, lower, capital):
    # Skip names (mostly capitalised) and fragments.
    return (
        2 <= len(word) <= 12
        and lower[word] >= 3 * max(1, capital[word]) / 2
        and word not in {'ll', 've', 're', 'em', 'th', 'st', 'nd'}
    )


def main():
    g_lower, g_cap = count(GENERAL)
    g_total = sum(g_lower.values())
    common = [w for w, _ in g_lower.most_common() if usable(w, g_lower, g_cap)]
    common = common[:1500]
    with open(os.path.join(HERE, 'common_words.txt'), 'w') as f:
        f.write('\n'.join(w.upper() for w in common) + '\n')

    r_lower, r_cap = count(RADIO)
    r_total = sum(r_lower.values())
    top_general = set(common[:400])
    scored = []
    for w, n in r_lower.items():
        if n < 8 or w in top_general or not usable(w, r_lower, r_cap):
            continue
        if len(w) < 3:
            continue
        ratio = (n / r_total) / ((g_lower[w] + 1) / g_total)
        scored.append((math.log(ratio) * math.log(n), w, n))
    scored.sort(reverse=True)
    with open(os.path.join(HERE, 'radio_candidates.txt'), 'w') as f:
        for score, w, n in scored[:400]:
            f.write(f'{w.upper()}\t{n}\t{score:.1f}\n')
    print(len(common), 'common;', len(scored), 'radio candidates')


if __name__ == '__main__':
    main()
