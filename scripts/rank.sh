#!/bin/sh
# agent-os relevance ranker. Reads .agent-os/prompts/index.jsonl and returns only the
# highest-scoring entries, so a scan loads a handful of lines instead of every task or
# error. Replaces "grep the index and open anything that looks strong" -- strong was
# never defined, so the judgement drifted from session to session.
#
# Usage:
#   sh .agent-os/scripts/rank.sh -q "keywords here" [-f path1,path2] [-k task|error] [-n 8]
#
#   -q  query words, whitespace separated. Matched case-insensitively.
#   -f  paths you are about to touch, comma separated. A hit here outranks everything.
#   -k  restrict to tasks or errors. Default: both.
#   -n  how many lines to return. Default 8.
#
# Output: one line per hit, "SCORE<TAB><the index line>", best first. Entries scoring
# zero are dropped. Exit 2 (with a message on stderr) when there is no index, so a
# caller can fall back to grepping.
#
# Scoring
#   base  = 3*tags + 3*kw + 2*area + 1*summary + 1*rc     (per query word, presence)
#   score = base * sev_w * rec_w * age_w * open_w
#         + 10 if a -f path meets the entry's files
#         + 0.5 * refs
#         + 2 if pinned
# The file hit is added, not multiplied, on purpose: a past error about a file you are
# editing has to surface even when no keyword matched. It only reaches about 20% of
# documents (files is that sparsely filled), so a miss means no information.

# See reindex.sh: awk byte-vs-character semantics and LC_COLLATE glob order both vary
# by locale, silently. The inline LC_ALL=C on the awk call below predates this and is
# now redundant; it stays because uchars() is only valid under C and that is where a
# reader looks for the reason. Task 17.
export LC_ALL=C

AOS=".agent-os"
root=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
cd "$root" || exit 2
idx="$AOS/prompts/index.jsonl"

Q=""; FILT=""; KIND=""; N=8
while [ $# -gt 0 ]; do
  # Every option here takes a value, so the missing-value check belongs to the loop,
  # not to each branch. Without it `shift 2` on a one-argument tail failed, $# never
  # shrank, and the loop spun forever -- the search command hung its caller.
  [ $# -ge 2 ] || { echo "rank.sh: $1 needs a value" >&2; exit 2; }
  case "$1" in
    -q) Q="$2"; shift 2 ;;
    -f) FILT="$2"; shift 2 ;;
    -k) KIND="$2"; shift 2 ;;
    # An unchecked -n reached `head -n` directly. 0 and negatives printed nothing and
    # exited 0 -- indistinguishable from "no related prior work", which the protocol
    # says to accept and move on from. A search must not be able to report empty
    # because of how it was called. See E0003.
    -n) case "$2" in *[!0-9]*) echo "rank.sh: -n needs a positive integer, got [$2]" >&2; exit 2 ;; esac
        [ "$2" -ge 1 ] || { echo "rank.sh: -n must be >= 1, got [$2]" >&2; exit 2; }
        N="$2"; shift 2 ;;
    *) echo "rank.sh: unknown option $1" >&2; exit 2 ;;
  esac
done

[ -f "$idx" ] || { echo "rank.sh: no $idx (run reindex.sh, or fall back to a frontmatter scan)" >&2; exit 2; }

# Age buckets as dates, so awk only has to compare YYYY-MM-DD strings. Same portable
# ladder agent-os-compact.sh uses: GNU date, BSD date, perl, python3.
ago() {
  date -d "$1 days ago" +%Y-%m-%d 2>/dev/null \
    || date -v-"$1"d +%Y-%m-%d 2>/dev/null \
    || perl -e 'use POSIX; print strftime("%Y-%m-%d", localtime(time-86400*$ARGV[0]))' "$1" 2>/dev/null \
    || python3 -c 'import sys,datetime; print((datetime.date.today()-datetime.timedelta(days=int(sys.argv[1]))).isoformat())' "$1" 2>/dev/null \
    || true
}
D30=$(ago 30); D180=$(ago 180)
# Without a usable date command every entry lands in the neutral bucket rather than
# the stale one, so a missing tool cannot silently bury recent documents.
[ -n "$D30" ]  || D30="0000-00-00"
[ -n "$D180" ] || D180="0000-00-00"

# Optional per-project alias map. Absent -> no expansion, everything else unchanged.
VOCAB="$AOS/vocab.txt"
[ -f "$VOCAB" ] || VOCAB=""

# LC_ALL=C pins awk to byte semantics on EVERY platform. Without it macOS awk
# (one-true-awk) counts length()/substr() in bytes while GNU awk in a UTF-8 locale
# counts characters, so the destem guard below fired on Linux/Windows and never on
# macOS -- the same query stemmed differently per machine. Byte semantics everywhere
# is the only setting both implementations agree on. tolower() becomes ASCII-only
# (Korean and Japanese have no case, so nothing is lost) and the bracket ranges in
# termhit() become plain byte ranges. See task 14.
LC_ALL=C awk -v query="$Q" -v filt="$FILT" -v kindf="$KIND" -v d30="$D30" -v d180="$D180" -v vocab="$VOCAB" '
function uchars(s,   c) {
  # Character count of a UTF-8 string under byte semantics: every continuation byte
  # is 10xxxxxx (\200-\277), so dropping them leaves exactly one byte per character.
  # Only safe under LC_ALL=C -- a UTF-8-locale BSD awk dies with "towc: multibyte
  # conversion failure" the moment a regex touches a lone continuation byte.
  c = s
  gsub(/[\200-\277]/, "", c)
  return length(c)
}
function clearF(   i) {
  for (i in F) delete F[i]
}
function parse(s,   i, L, k, v, c) {
  # The index line is written by reindex.sh, which escapes every backslash and quote
  # inside a value. So a bare quote always ends a value, and walking the line once is
  # enough -- no regex, no ambiguity about where a field stops.
  clearF()
  L = length(s); i = 2
  while (i <= L) {
    if (substr(s, i, 1) != "\"") break
    i++; k = ""
    while (i <= L && substr(s, i, 1) != "\"") { k = k substr(s, i, 1); i++ }
    i += 2                                   # closing quote of the key, then the colon
    if (substr(s, i, 1) == "\"") {
      i++; v = ""
      while (i <= L) {
        c = substr(s, i, 1)
        if (c == "\\") { v = v substr(s, i + 1, 1); i += 2; continue }
        if (c == "\"") { i++; break }
        v = v c; i++
      }
    } else {
      v = ""
      while (i <= L) {
        c = substr(s, i, 1)
        if (c == "," || c == "}") break
        v = v c; i++
      }
    }
    F[k] = v
    if (substr(s, i, 1) == ",") i++; else break
  }
}
function hits(field, weight,   g, j, n) {
  # Scored per CONCEPT GROUP, not per surface form. A group is one query word plus,
  # when vocab.txt supplied them, its translations. A document carrying three
  # spellings of the same concept must not outscore one carrying it once -- otherwise
  # turning on the alias map would itself be the false-positive source.
  if (field == "" || ng == 0) return 0
  field = tolower(field)
  n = 0
  for (g = 1; g <= ng; g++) {
    for (j = 1; j <= gn[g]; j++) {
      if (index(field, gt[g, j]) > 0) { n += weight; break }
    }
  }
  return n
}
function sevw(v) {
  if (v == "critical") return 3.0
  if (v == "high")     return 2.0
  if (v == "low")      return 0.5
  return 1.0                                  # medium, and tasks, which carry no severity
}
function openw(v) {
  # status has drifted badly across installs (resolved with suffixes, prevention-active,
  # in_progress, INDEX-..., planned with commentary). Testing for the two CLOSED prefixes
  # is stable under that drift; anything else counts as still open.
  v = tolower(v)
  if (v ~ /^completed/ || v ~ /^resolved/) return 1.0
  return 1.5
}
function agew(d) {
  if (d == "") return 1.0
  if (d >= d30)  return 1.5
  if (d >= d180) return 1.0
  return 0.6
}
function filehit(files,   i, f) {
  if (files == "" || nf == 0) return 0
  files = tolower(files)
  for (i = 1; i <= nf; i++) {
    f = fw[i]
    if (f == "") continue
    # either direction: the index may hold a directory that contains the query path,
    # or a full path that the query names only in part.
    if (index(files, f) > 0) return 10
    if (index(f, files) > 0) return 10
  }
  return 0
}
function destem(w) {
  # Korean attaches particles to the word, so a raw query word misses the same word
  # in an index field: "테스트를" does not contain, and is not contained by, "테스트".
  # Measured on the golden set -- this was the single biggest cause of misses.
  # Applied to QUERY WORDS ONLY; the index keeps whatever the document wrote.
  # Cross-language vocabulary (a Korean query against Japanese or English tags) is a
  # different problem and is task 05, not this.
  #
  # uchars(), not length(): a Korean syllable is 3 bytes, so under byte semantics
  # length() never drops below 3 and this guard never fired on macOS -- "결과" was
  # stemmed to "결", "나" to the empty string. Task 14.
  if (uchars(w) < 3) return w
  sub(/(으로서|으로써|에서는|에게서|이라고|라고|으로|에서|에게|부터|까지|처럼|만큼|보다|이라|하고|들의|들을|들이)$/, "", w)
  sub(/(을|를|이|가|은|는|에|의|와|과|도|만|로|랑|나)$/, "", w)
  return w
}
function termhit(q, t) {
  # Short ASCII aliases need word boundaries: "ui" is inside "build", "db" inside
  # "adb". CJK terms are matched as plain substrings -- Japanese queries have no
  # spaces to split on, so substring is the only thing that works there.
  if (t ~ /^[a-z0-9_-]+$/ && length(t) <= 3)
    return (" " q " ") ~ ("[^a-z0-9_]" t "[^a-z0-9_]")
  return index(q, t) > 0
}
function loadvocab(path, q,   line, canon, rest, n, a, i, matched) {
  # vocab.txt: one concept per line, "canonical: alias, alias, ...". A line joins the
  # query when any of its terms appears in the raw query string, and then the whole
  # line becomes one group. The documents are never rewritten -- only the query grows.
  if (path == "") return
  while ((getline line < path) > 0) {
    gsub(/\r/, "", line)
    sub(/^[ \t]+/, "", line)
    if (line == "" || substr(line, 1, 1) == "#") continue
    i = index(line, ":")
    if (i == 0) continue
    canon = tolower(substr(line, 1, i - 1))
    rest  = tolower(substr(line, i + 1))
    gsub(/^[ \t]+|[ \t]+$/, "", canon)
    n = split(canon "," rest, a, ",")
    matched = 0
    for (i = 1; i <= n; i++) {
      gsub(/^[ \t]+|[ \t]+$/, "", a[i])
      if (a[i] != "" && termhit(q, a[i])) { matched = 1; break }
    }
    if (!matched) continue
    ng++
    for (i = 1; i <= n; i++) if (a[i] != "") gt[ng, ++gn[ng]] = a[i]
  }
  close(path)
}
function covered(w,   g, j) {
  for (g = 1; g <= ng; g++)
    for (j = 1; j <= gn[g]; j++)
      if (gt[g, j] == w) return 1
  return 0
}
BEGIN {
  q = tolower(query)
  nq = split(q, qw, /[ \t]+/)
  if (nq == 1 && qw[1] == "") nq = 0

  # Vocabulary groups first, then any query word they did not already absorb.
  # Order matters: adding a word that its own alias line already contains would
  # score the same concept twice, which doubled scores in testing.
  ng = 0
  if (q != "") loadvocab(vocab, q)
  for (qi = 1; qi <= nq; qi++) {
    w = destem(qw[qi])
    if (w == "" || covered(w)) continue
    ng++; gt[ng, 1] = w; gn[ng] = 1
  }

  nf = split(tolower(filt), fw, /,/)
  if (nf == 1 && fw[1] == "") nf = 0
}
{
  parse($0)
  if (kindf != "" && F["k"] != kindf) next
  base = hits(F["tags"], 3) + hits(F["kw"], 3) + hits(F["area"], 2) \
       + hits(F["summary"], 1) + hits(F["rc"], 1) + hits(F["path"], 1)
  rec = F["rec"] + 0; if (rec < 1) rec = 1
  recw = 1 + 0.5 * (rec - 1); if (recw > 3.0) recw = 3.0
  fh = filehit(F["files"])
  # An entry needs a real relevance signal -- a matched word or a touched file.
  # refs and pin only amplify relevance; on their own they would put every pinned
  # document in every result, which is the flat-scan noise this replaces.
  if (base == 0 && fh == 0) next
  score = base * sevw(F["sev"]) * recw * agew(F["date"]) * openw(F["status"])
  score += fh
  score += 0.5 * (F["refs"] + 0)
  if (F["pin"] == "true") score += 2
  if (score > 0) printf "%.1f\t%s\n", score, $0
}
' "$idx" | LC_ALL=C sort -k1,1rn | head -n "$N"
