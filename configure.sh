#!/usr/bin/env bash
set -euo pipefail
shopt -s nullglob
cd "$(dirname "$0")"

# your name, as it should appear in output filenames (no spaces)
NAME=Your_Name
RESUME_PDF=$NAME.pdf

OUT_DIR=pdfs
RESUME_SRC=resume.tex
SRC_DIR=letters
TEMPLATE=cover_letter.tex

AUX_DIR=.build
BUILD_FILE=build.ninja

# written to a temp file and moved into place, so a mid-run error leaves the
# previous build.ninja intact rather than a half-written one
tmp=$(mktemp $BUILD_FILE.XXXXXX)
meta_tmpl=$(mktemp)
trap 'rm -f "$tmp" "$meta_tmpl"' EXIT

# \$ in the helpers below is a ninja variable, expanded by ninja at build
# time, not by bash
write() {
    echo "$@" >> "$tmp"
}

variable() {
    write "$1 = $2"
}

rule() {
    local name=$1
    shift

    write "rule $name"
    write "  command = $@"
    write "  description = PDF \$out"
    write
}

build() {
    local output=$1
    shift

    write "build $output: $@"
}

binding() {
    write "  $1 = $2"
}

# PDF-name style: underscores, case preserved. new.sh slugs source files as
# lowercase-with-dashes; the two conventions are deliberately different.
slugify() {
    printf '%s' "$1" | sed 's/[^A-Za-z0-9]\+/_/g; s/^_//; s/_$//'
}

# let pandoc read the frontmatter, so the filename can't disagree with the PDF
frontmatter() {
    local md=$1

    # a trailing empty field is dropped by pandoc, so read hits EOF and returns
    # non-zero; tolerate it rather than letting set -e abort here
    { read -r company || true; read -r role || true; } \
        < <(pandoc --template="$meta_tmpl" -t plain "$md")
}

die() {
    echo "$@" >&2
    exit 1
}

printf '$company$\n$role$\n' > "$meta_tmpl"

for file in "$TEMPLATE" "$RESUME_SRC"; do
    [[ -f $file ]] || die "$file: not found -- supply your own (see README)"
done

# the resume has no date of its own; use its last commit so clones reproduce
resume_epoch=$(git log -1 --format=%ct -- "$RESUME_SRC" 2>/dev/null || true)
[[ -n $resume_epoch ]] || resume_epoch=$(stat -c %Y "$RESUME_SRC")

# output path -> the letter that claimed it, so a collision can name both
declare -A claimed_by=()

variable template "$TEMPLATE"
variable auxdir "$AUX_DIR"
write

rule \
    pandoc \
    "SOURCE_DATE_EPOCH=\$epoch FORCE_SOURCE_DATE=1 pandoc --pdf-engine=latexmk --template=\$template -V date=\"\$date\" -o \$out \$in"

rule \
    latexmk \
    "SOURCE_DATE_EPOCH=\$epoch FORCE_SOURCE_DATE=1 latexmk -pdf -quiet -auxdir=\$auxdir -jobname=\$jobname \$in"

build "$RESUME_PDF" latexmk "$RESUME_SRC"
binding jobname "$NAME"
binding epoch "$resume_epoch"
write

for md in "$SRC_DIR"/*.md; do
    stem=$(basename "$md" .md)
    iso=${stem:0:10}

    # check the shape first: date -d '' silently means "today"
    [[ $iso =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]] \
        || die "$md: filename must start with an ISO date, YYYY-MM-DD-company-role.md"
    header_date=$(date -d "$iso" '+%-d %B %Y' 2>/dev/null) \
        || die "$md: $iso is not a real date"

    frontmatter "$md"
    [[ -n $role ]] || die "$md: frontmatter needs a 'role:'"

    stub=$NAME
    [[ -z $company ]] || stub=$stub-$(slugify "$company")
    pdf="$OUT_DIR/$stub-$(slugify "$role").pdf"

    [[ -z ${claimed_by[$pdf]:-} ]] \
        || die "$md: output name collides with ${claimed_by[$pdf]} ($pdf)"
    claimed_by[$pdf]=$md

    build "$pdf" pandoc "$md" '|' '$template'
    binding date "$header_date"
    binding epoch "$(date -d "$iso" +%s)"
done

mv "$tmp" "$BUILD_FILE"
