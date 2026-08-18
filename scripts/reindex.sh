#!/bin/sh
# agent-os indexer. Builds .agent-os/prompts/index.jsonl (one compact line per task, error,
# and decision record)
# so routing skills scan ONE small file instead of globbing every doc.
# Each line carries the eviction signals: refs (inbound references), updated date, pin, status.
#
# Fields, in line order:
#   k id status cat area tags date refs pin   -- routing and eviction
#   date   last_seen, else date, else updated, else created  -- the LAST touch, not the first
#   sev    normalized severity, "" on tasks   -- low | medium | high | critical
#   rec    occurrence count, always >= 1      -- from `recurrence` (count or list form)
#   recof  prior error ids, "" when unused    -- the list form of `recurrence`
#   files  related paths, comma joined        -- path matching
#   kw     `keywords`, second search key      -- separate from tags
#   rc     `root_cause`                       -- first-pass recurrence matching
#   summary path                              -- summary is NOT truncated; see below
#
# Summary is kept whole on purpose. Capping it at 160 characters was measured on a
# 261-document repo: it damages 55% of the documents to save 27KB while the added
# signal fields cost 34KB, so the index grows either way. Index size is a context
# cost only when the whole file is read; the ranking step reads it in a process and
# returns a handful of lines.
#
# Usage:
#   sh .agent-os/scripts/reindex.sh              # rebuild the index
#   sh .agent-os/scripts/reindex.sh --emit FILE KIND   # print one JSON line (internal helper)
#
# Performance note (task 12): the whole index is produced by ONE grep and ONE awk.
# The previous version forked about 60 processes per document, which cost ~13s per
# document on Windows (MSYS2) where process creation is expensive -- 43 minutes for
# a 260-document repo.
#
# The file list is passed to awk on STDIN, never through xargs. xargs splits into
# several processes once the argument list is long enough, and each process would
# keep its own reference-count table, silently undercounting refs on large repos
# (observed on a 260-document repo: refs total 539 against a true 827). Entry count
# stays correct in that failure mode, so it does not show up in a line-count check.

# Locale is pinned in every agent-os script. Two things vary without it and both are
# silent. awk counts length()/substr() in BYTES on macOS and in CHARACTERS under GNU
# awk in a UTF-8 locale. And shell glob expansion sorts by LC_COLLATE, so the same
# repo indexed on two machines yields the same entries in a different ORDER -- where
# index.jsonl is tracked, that is a diff every contributor flips back. Task 17.
export LC_ALL=C

AOS=".agent-os"

# Marks the end of the reference pool on awk stdin. grep only emits lines matching
# the related-key regex below, so no pool line can collide with it.
SEP="#--agent-os-file-list--"

# Every inbound-reference line in one pass. awk splits them into the two pools:
# a task id is matched only against fields that name a task (related_tasks, generic
# related, and an error's `task:`); an error id only against related_errors / related.
# Scoping them apart keeps a bare 2-digit task id from colliding with an error id.
relpool() {
  grep -rhE '^(related_tasks|related|task|related_errors):' "$AOS/prompts" 2>/dev/null
}

# stdin = <pool lines> SEP <one "KIND PATH" line per document>
AWK_EMIT='
function esc(s,   out, i, c, L) {
  # JSON string escaping, byte-identical to the v1 sed pass: s/\\/\\\\/g; s/"/\\"/g
  # Written as a character loop on purpose: awk gsub replacement strings treat
  # backslash and & specially, and that handling varies between awk implementations.
  if (index(s, "\\") == 0 && index(s, "\"") == 0) return s
  out = ""; L = length(s)
  for (i = 1; i <= L; i++) {
    c = substr(s, i, 1)
    if (c == "\\") out = out "\\\\"
    else if (c == "\"") out = out "\\\""
    else out = out c
  }
  return out
}

function read_fm(path,   line, ln) {
  # Mirrors v1: line 1 must open with ---, then collect until the next --- line.
  # A file with no frontmatter yields zero fields rather than an error, and an
  # empty file still produces an entry.
  nfm = 0; ln = 0
  while ((getline line < path) > 0) {
    gsub(/\r/, "", line)
    ln++
    if (ln == 1) { if (line !~ /^---/) break; else continue }
    if (line ~ /^---/) break
    fm[++nfm] = line
  }
  close(path)
}

function get(name,   i, v) {
  # First frontmatter line keyed by name, with one layer of [ ] and " " peeled off,
  # in the same order the v1 sed chain applied them.
  for (i = 1; i <= nfm; i++) {
    if (fm[i] ~ ("^" name ":")) {
      v = fm[i]
      sub("^" name ":[ \t]*", "", v)
      sub(/^\[/, "", v)
      sub(/\]$/, "", v)
      sub(/^"/, "", v)
      sub(/"$/, "", v)
      return v
    }
  }
  return ""
}

function sevnorm(v) {
  # severity drifted to 9 values across the installs (measured 2026-08-12, 315 docs):
  # high 133 / medium 126 / low 32 / critical 16 / minor 3 / notice 2 / HIGH 1 /
  # medium-high 1 / M 1. Ranking multiplies by this, so normalize here instead of
  # letting unknown spellings fall through to a neutral weight.
  # Validating the raw frontmatter value is task 03; this only makes the index usable.
  v = tolower(v)
  if (v == "m") return "medium"
  if (v == "minor" || v == "notice") return "low"
  if (v == "medium-high") return "high"
  return v
}

function reccount(v,   n, a) {
  # `rec` means "how many times this has bitten", never below 1 -- it happened at
  # least once or the document would not exist.
  #
  # The installs do not agree on what `recurrence` counts, so this normalizes:
  #   absent / empty        -> 1
  #   0                     -> 1   (one install writes 0 for "never came back";
  #                                 taken literally that would rank a quiet error
  #                                 BELOW neutral, since rec_w = 1 + 0.5*(rec-1))
  #   N                     -> N   (some count occurrences, some count repeats. Both
  #                                 rise with severity, which is all ranking needs;
  #                                 reinterpreting either one would be guessing.)
  #   list of K prior ids   -> K+1 (this occurrence plus the ones it repeats)
  if (v == "") return 1
  if (v ~ /^[0-9]+$/) return (v + 0 < 1) ? 1 : v + 0
  n = split(v, a, ",")
  return n + 1
}

function unqlist(v) {
  # `keywords: ["a", "b"]` -- get() peels one outer bracket and one outer quote pair,
  # which leaves the INNER quotes sitting on every separator: `a", "b`. tags: is
  # usually written unquoted so it never showed, and matching still worked because the
  # scorer looks for substrings, so this sat there looking like a formatting quirk.
  # A multi-word keyword would not have matched, though. Only the separator sequence is
  # rewritten; an item that genuinely contains `", "` is the one case this flattens.
  gsub(/"[ 	]*,[ 	]*"/, ", ", v)
  return v
}

function recchain(v,   out) {
  # The list form only. Quotes and spaces are stripped so task 04 can consume it
  # directly; the unmodified value stays in the .md.
  if (v == "" || v ~ /^[0-9]+$/) return ""
  out = v
  gsub(/["[:space:]]/, "", out)
  return out
}

function wcount(s, pat,   n, P, L, pos, off, b, a) {
  # Whole-word occurrence count, matching `grep -ow PAT` on the joined pool.
  # Newline is a non-word character, so line-start and line-end boundaries fall out.
  # The leading index() is what keeps this cheap: ids absent from the pool cost one
  # C-level scan and nothing else.
  # ponytail: pat is compared literally, while grep would read it as a BRE. Only
  # diverges for ids carrying regex metacharacters; ids here are [0-9A-Za-z_-].
  if (pat == "") return 0
  n = 0; P = length(pat); L = length(s); off = 0
  while ((pos = index(substr(s, off + 1), pat)) > 0) {
    pos = off + pos
    b = (pos == 1)     ? "" : substr(s, pos - 1, 1)
    a = (pos + P > L)  ? "" : substr(s, pos + P, 1)
    if (b !~ /[A-Za-z0-9_]/ && a !~ /[A-Za-z0-9_]/) { n++; off = pos + P - 1 }
    else off = pos
  }
  return n
}

function emit(path, kind,   id, status, summary, area, tags, cat, pin, d, refs, pool,
                           sev, recraw, rec, recof, files, kw, rc) {
  read_fm(path)
  # No type: in the frontmatter means this is not a prompt document -- a directory
  # README, a scratch note, anything someone dropped in the folder. Indexing it
  # produced an entry with an empty id and an empty summary that matched nothing and
  # sat in the corpus forever. check-prompts still fails loudly on a REAL document
  # that lost its frontmatter, so nothing goes missing quietly; it just stops the
  # index from carrying blanks. Same rule the input counter uses, so the two agree
  # on what a document is.
  if (get("type") == "") return
  id = get("id"); status = get("status"); summary = get("summary")
  area = unqlist(get("area")); tags = unqlist(get("tags")); cat = get("category"); pin = get("pin")
  # last_seen wins so a trap that recurred recently does not read as stale. `date`
  # keeps the first occurrence in the .md; only the ranking and archival view moves.
  d = get("last_seen")
  if (d == "") d = get("date")
  if (d == "") d = get("updated")
  if (d == "") d = get("created")
  if (pin != "true") pin = "false"

  # Weighting signals (task 01). Every name here is one the installs already use --
  # none is invented. `last_seen` was considered and dropped: zero documents across
  # all installs carry it, and `date` above already resolves to the last touch.
  sev    = sevnorm(get("severity"))       # normalized; "" on tasks
  recraw = get("recurrence")
  rec    = reccount(recraw)               # occurrences, always >= 1
  recof  = recchain(recraw)               # prior error ids when the list form is used
  files  = unqlist(get("files"))                   # path matching -- the strongest single signal
  kw     = unqlist(get("keywords"))                # second search key, separate from tags
  rc     = get("root_cause")              # first-pass key for recurrence matching
  cby    = get("caught_by")               # self|review|user|runtime -- not scored, counted
  if (rc == "") rc = get("cause")         # installs that shortened the key still get indexed

  # An unknown kind sees both pools, as the v1 relpool fallback did. A `related:`
  # line is in both, so it is counted twice there -- same as v1.
  pool = (kind == "task") ? tpool : (kind == "error") ? epool : tpool epool
  refs = wcount(pool, id)

  # New keys sit between pin and summary. agent-os-compact.sh parses this line with
  # greedy sed patterns that take the LAST match of a key, so anything placed after
  # summary or path could be shadowed by prose; inserting before summary adds no
  # exposure that summary did not already have.
  printf "{\"k\":\"%s\",\"id\":\"%s\",\"status\":\"%s\",\"cat\":\"%s\",\"area\":\"%s\",\"tags\":\"%s\",\"date\":\"%s\",\"refs\":%d,\"pin\":%s,\"sev\":\"%s\",\"rec\":%d,\"recof\":\"%s\",\"files\":\"%s\",\"kw\":\"%s\",\"rc\":\"%s\",\"cby\":\"%s\",\"summary\":\"%s\",\"path\":\"%s\"}\n", \
    esc(kind), esc(id), esc(status), esc(cat), esc(area), esc(tags), esc(d), \
    refs, pin, esc(sev), rec, esc(recof), esc(files), esc(kw), esc(rc), esc(cby), \
    esc(summary), esc(path)
}

!past_sep {
  if ($0 == sep) { past_sep = 1; next }
  line = $0
  gsub(/\r/, "", line)
  if (line ~ /^related_tasks:/ || line ~ /^task:/ || line ~ /^related:/) tpool = tpool line "\n"
  if (line ~ /^related_errors:/ || line ~ /^related:/)                   epool = epool line "\n"
  next
}
$0 != "" {
  k = $0; sub(/ .*/, "", k)          # first field is the kind
  p = $0; sub(/^[^ ]* /, "", p)      # rest is the path, spaces and all
  emit(p, k)
}
'

if [ "$1" = "--emit" ]; then
  { relpool; printf '%s\n' "$SEP"; printf '%s %s\n' "$3" "$2"; } | awk -v sep="$SEP" "$AWK_EMIT"
  exit 0
fi

root=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
cd "$root" || exit 2
[ -d "$AOS/prompts" ] || { echo "no $AOS/prompts here"; exit 0; }

# A caller can redirect the output. portability-test needs to see what this
# script PRODUCES under four locales, and the only way to do that used to be
# rewriting the tracked index four times -- which swept another session's
# uncommitted documents into it once, and leaves the file in an unknown state
# if the run is interrupted. A test that mutates what it inspects is not a test.
out="${AGENT_OS_INDEX_OUT:-$AOS/prompts/index.jsonl}"
# Sweep orphans from earlier interrupted runs. The glob test keeps this from forking
# rm on every run. ponytail: assumes no concurrent reindex; single-user repos only.
for orphan in "$out".tmp.*; do
  [ -e "$orphan" ] && rm -f "$out".tmp.*
  break
done
tmp="$out.tmp.$$"
trap 'rm -f "$tmp"' EXIT INT TERM

# Collect "KIND PATH" lines with shell builtins only (no forks), tasks before errors,
# then hand the whole list to the single awk pass.
set --
for f in "$AOS"/prompts/tasks/*.md "$AOS"/prompts/tasks/completed/*.md; do
  [ -e "$f" ] || continue
  case "$f" in */_TEMPLATE.md|*/manual-*.md|*/README.md) continue ;; esac
  set -- "$@" "task $f"
done
for f in "$AOS"/prompts/errors/*.md; do
  [ -e "$f" ] || continue
  case "$f" in */_TEMPLATE.md|*/manual-*.md|*/README.md) continue ;; esac
  set -- "$@" "error $f"
done

# Decision records live under docs/, not prompts/, but they have to be searchable:
# the point of writing down a rejected option is that the next person finds it before
# proposing it again. Their ids never collide with task ids, so they share the task
# reference pool.
for f in "$AOS"/docs/adr/*.md; do
  [ -e "$f" ] || continue
  case "$f" in */_TEMPLATE.md|*/manual-*.md|*/README.md) continue ;; esac
  set -- "$@" "adr $f"
done

if [ $# -gt 0 ]; then
  { relpool; printf '%s\n' "$SEP"; printf '%s\n' "$@"; } | awk -v sep="$SEP" "$AWK_EMIT" > "$tmp"
else
  : > "$tmp"
fi

mv "$tmp" "$out"
echo "reindexed: $(wc -l < "$out") entries -> $out"
