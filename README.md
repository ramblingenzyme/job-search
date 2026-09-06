# job-search
Small ninja build system around pandoc to streamline writing cover letters and resume in LaTeX

# AI BELOW

## What to replace

It builds as-is. Two files are deliberately minimal — enough to render, no
design — and are meant to be replaced with your own:

- `cover_letter.tex` — a **pandoc LaTeX template** (contract below)
- `resume.tex` — a standalone LaTeX resume, plain LaTeX rather than a template

Set `NAME` at the top of `configure.sh` to your own name first; it prefixes
every output filename, so keep it free of spaces.

Requires `pandoc`, `ninja`, and a TeX distribution with `latexmk`.



## Usage

```sh
./new.sh "Example Co" "Senior Software Engineer"   # create a dated stub, opens $EDITOR
./configure.sh                                     # regenerate build.ninja
ninja                                              # build
```

Re-run `./configure.sh` when you add, remove or rename a letter. Editing a
letter's contents or the template just needs `ninja`. `ninja -t clean` removes
the generated PDFs.

## Letters

One markdown file per letter in `letters/`, named `YYYY-MM-DD-company-role.md`. The date
comes from the **filename**, not the frontmatter, and renders in the header as
e.g. `26 August 2026`.

```yaml
---
role: Senior Platform Engineer
company: Example Co
greeting: "Hi Example Co team,"
# signoff: defaults to "Kind regards,"
# signature: defaults to whatever your template's fallback is
---

Body paragraphs in markdown.
```

Output is `pdfs/<NAME>-<company>-<role>.pdf`. Two letters producing the same
name is a configure-time error — give one a more specific `role`.

## Template contract

`cover_letter.tex` is passed to `pandoc --template`, so `$…$` is pandoc's
interpolation syntax, not LaTeX math. It must use:

| Variable | |
|---|---|
| `$body$` | the converted markdown — required |
| `$role$` `$company$` `$date$` | frontmatter, plus the date derived from the filename |
| `$greeting$` `$signoff$` `$signature$` | frontmatter; wrap in `$if(x)$…$else$…$endif$` to give defaults |

Three things a hand-written letter doesn't need but a template does:

- **Escape literal dollars as `$$`.** `$|$` is read as a variable named `|` and
  silently vanishes; write `$$|$$` to emit `$|$`. (A bare `|` in text mode
  renders as an em dash under OT1 — use `$$|$$` or `\usepackage[T1]{fontenc}`.)
- **Define `\tightlist`.** Pandoc emits it for any markdown list without blank
  lines between items, and assumes its own default template defines it:
  ```latex
  \providecommand{\tightlist}{%
    \setlength{\itemsep}{0pt}\setlength{\parskip}{0pt}}
  ```
- **Add `\pdftrailerid{}`** for reproducible output — needed in the pandoc
  template, but not in `resume.tex`. See below.

## Reproducible builds

Every PDF is byte-identical across rebuilds, so an unchanged letter never shows
up as modified in `git status`. Two things do it:

- `SOURCE_DATE_EPOCH` pins `/CreationDate` and `/ModDate`. Letters use their own
  date; the resume uses the last commit touching `resume.tex`, falling back to
  mtime. This covers metadata only, which is enough because the templates never
  read TeX's clock -- dates come from `$date$`, so don't introduce `\today`.
- `\pdftrailerid{}` in `cover_letter.tex`. pdfTeX hashes the creation date *and
  the output path* into the trailer `/ID`; pandoc invokes the engine with
  `-outdir` set to a fresh temp directory each run, so that path varies even
  with the date pinned. An empty argument omits `/ID`; a fixed non-empty string
  keeps a stable one. `resume.tex` needs neither — it builds with no `-outdir`.

## Layout

| Path | |
|---|---|
| `configure.sh` | generates `build.ninja` |
| `new.sh` | creates a dated letter stub |
| `letters/*.md` | one letter each |
| `pdfs/` | output |
| `.build/` | latexmk intermediates (gitignored) |
