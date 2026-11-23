# arxiv-export

> Export a Markdown academic paper into an **arXiv-ready, recompilable LaTeX submission package** — with a local PDF proof.

A Claude Code skill that turns a finished Markdown paper (e.g. produced by
`academic-paper` or `writing-editorial`) into LaTeX source that **recompiles
cleanly on arXiv's TeXLive**, plus a `submission.tar.gz` ready to upload.

[中文说明](README-zh.md)

## Why a dedicated skill

Markdown authors almost always hit two problems that make a naive
`pandoc file.md -o out.pdf` fail or produce poor typesetting:

1. **Math has no `$` delimiters.** Authors write formulas as plain text
   (e.g. `φ(p) = A(p) − B⁺(p)`). LaTeX never enters math mode → spacing and
   italics are wrong, and glyphs like `⟺ ⊆ ⁺ ₀` are missing from standard fonts.
2. **References are a Markdown list, not BibTeX**; theorems have no `amsthm`
   environments; chapters are scattered across several `ch*.md` files.

This skill treats those as **first-class scenarios**. The hard part (math
delimiting + unicode conversion) is done by per-block agents with a mandatory
spot-check loop; the deterministic parts are scripted.

## The 6-phase pipeline

```
Markdown draft
   │
   ▼
 Phase 0  Preflight — toolchain check + source inventory + difficulty sizing
   │        (no pandoc/tectonic → asks consent, then brew-installs)
   ▼
 Phase 1  Math delimiting + unicode→LaTeX  (per-block agents; the critical step)
   │        [MUST] spot-check loop guards against altered math
   ▼
 Phase 2  Structure → LaTeX  (preamble + amsthm theorem environments)
   │
   ▼
 Phase 3  References → bibliography  (BibTeX/\cite, or embedded thebibliography)
   │
   ▼
 Phase 4  Compile verification  (tectonic / XeLaTeX / pdfLaTeX, ≤3 fix rounds)
   │
   ▼
 Phase 5  arXiv packaging  (.bbl or embedded bib, 00README, flatten, tar.gz, checklist)
```

### Safety rails

- **No system change without consent.** Phase 0 stops and asks before installing
  any toolchain component (`brew install tectonic pandoc`, etc.).
- **Math fidelity is sacred.** Phase 1 enforces a `[MUST]` spot-check: random
  segments are compared against the source to confirm no math content, symbol
  direction, or sub/superscript drifted. On a mismatch it retries the block,
  then pauses for you — it never silently ships altered math.
- **Never overwrites your Markdown.** All artifacts go to a `arxiv-build/`
  (or `$SCRATCH_DIR`) working directory.

## Install

```bash
git clone https://github.com/easyfan/arxiv-export.git
cd arxiv-export
./install.sh            # installs to ~/.claude/skills/arxiv-export/
./install.sh --dry-run  # preview
./install.sh --uninstall
```

Windows: `./install.ps1`.

**TeX toolchain:** none is required to install the skill. On first real run the
skill checks for a TeX engine and, with your consent, installs one
(`tectonic` + `pandoc` recommended — self-contained, no 4 GB MacTeX; XeTeX
under the hood). Note tectonic's first compile downloads packages/fonts on
demand (a few minutes, hundreds of MB) — that is normal, not a hang.

## Usage

In Claude Code, point it at your finished Markdown paper:

```
用 arxiv-export 把 main_en.md 导出成 arXiv 投稿包
export paper.md to an arXiv LaTeX submission
compile my markdown paper to a PDF for arXiv
```

Deliverables land in the build directory:

- `main.pdf` — local proof
- `submission.tar.gz` — the arXiv upload package
- `main.tex` — self-contained LaTeX source
- `EXPORT_REPORT.md` — workload, spot-check conclusions, warnings handled, open items

## Files installed

| Path | Purpose |
|------|---------|
| `skills/arxiv-export/SKILL.md` | 6-phase orchestration |
| `skills/arxiv-export/references/unicode-to-latex.md` | unicode→LaTeX map + residual-char scan |
| `skills/arxiv-export/references/latex-template.md` | amsart preamble, amsthm environments, code-block unicode, table conversion |
| `skills/arxiv-export/references/arxiv-packaging.md` | `.bbl` vs embedded bib, engine declaration, flattening, tar.gz, final checklist |

## Changelog

### v1.0.0 (2026-11-24)

First release. Hardened from a real end-to-end run exporting a 723-line,
bare-unicode math paper (0 `$`, ~890 unicode math chars, 24 refs, Lean code
blocks) to a clean 33-page arXiv package.

| Item | Change |
|------|--------|
| 6-phase pipeline | Preflight → math delimiting → structure → refs → compile → package |
| `[MUST]` spot-check loop | Phase 1 math-fidelity gate with retry + pause-for-user |
| Code-block unicode | listings `literate` does **not** fire under XeTeX/tectonic → use `escapeinside` to render `→ ¬ φ ⁺` without dropping glyphs |
| Year-drift guard | Phase 3 checks in-text years vs refs; on mismatch keeps citations verbatim via embedded `thebibliography` (no natbib year rewrite) |
| `Missing character` check | Phase 4 adds a dedicated scan (distinct from `Undefined control sequence`) |
| Long-abstract layout | default to amsart 10pt so title + abstract share page 1 |
| Theorem numbering | independent per-type counters + `\newtheorem*` for unnumbered statements, faithful to Markdown |

## License

MIT — see [LICENSE](LICENSE).
