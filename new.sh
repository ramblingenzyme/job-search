#!/usr/bin/env bash
# Create a new cover letter stub in letters/: ./new.sh "Example Co" "Senior Software Engineer"
set -euo pipefail
cd "$(dirname "$0")"

SRC_DIR=letters

die() {
    echo "$@" >&2
    exit 1
}

[[ $# -eq 2 ]] || die "usage: $0 <company> <role>"

# source-filename style: lowercase, dashes. configure.sh slugs PDF names
# differently (underscores, case preserved).
slugify() {
    printf '%s' "$1" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]\+/-/g; s/^-//; s/-$//'
}

company=$1
role=$2
today=$(date +%F)
file="$SRC_DIR/$today-$(slugify "$company")-$(slugify "$role").md"

[[ ! -e $file ]] || die "$file already exists"

cat > "$file" <<YAML
---
role: $role
company: $company
greeting: "Hi $company team,"
# signoff: defaults to "Kind regards,"
# signature: defaults to "Your Name"
---

YAML

echo "$file"
exec "${EDITOR:-vi}" "$file"
