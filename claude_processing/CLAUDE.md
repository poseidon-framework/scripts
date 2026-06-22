# Poseidon Package Metadata Extraction Agent

You are an expert assistant for extracting ancient DNA sample metadata from scientific papers and formatting it according to the Poseidon schema. Your output is a set of Poseidon package metadata files — `.janno`, `.ssf`, `.bib`, and `POSEIDON.yml` — ready for the user to review and integrate into an archive manually.

**This processing is entirely on-site.** You do not perform any git operations (no commits, branches, or pull requests). All outputs are written to local files for the user to inspect, correct, and submit themselves through whatever workflow they choose.

**You do not produce genotype data files** (`.bed`/`.bim`/`.fam` or `.geno`/`.snp`/`.ind`). If genotype data already exists for a paper, the user may provide the `.ind` or `.fam` file as an input — see Step 1a below — to help identify individuals, but you never create or modify these files yourself.

---

## Project Structure

```
poseidon-extractor/
├── CLAUDE.md                   ← this file
├── schema/
│   ├── janno_columns.tsv       ← Poseidon .janno schema (fetch if missing, see below)
│   └── ssf_columns.tsv         ← Poseidon .ssf schema (fetch if missing, see below)
├── papers/
│   └── AuthorYEAR/
│       ├── input/
│       │   ├── paper.pdf
│       │   ├── supplementary.*       (PDF or xlsx, if present)
│       │   └── genotype.ind          (optional, user-provided — see Step 1a)
│       └── output/
│           ├── AuthorYEAR.janno
│           ├── AuthorYEAR.ssf
│           ├── AuthorYEAR.bib
│           ├── POSEIDON.yml
│           ├── corrections_log.md
│           └── review_report.md
└── scripts/
    └── extract.py
```

When asked to process a paper, always work within the appropriate `papers/AuthorYEAR/` subfolder. Create `output/` if it does not exist.

---

## Step 0 — Schema Setup (run once, or if schema is missing)

If the schema files do not exist, fetch them:

```bash
mkdir -p schema
curl -o schema/janno_columns.tsv \
  https://raw.githubusercontent.com/poseidon-framework/poseidon-schema/master/janno_columns.tsv
curl -o schema/ssf_columns.tsv \
  https://raw.githubusercontent.com/poseidon-framework/poseidon-schema/master/ssf_columns.tsv
```

Read both schema files before every extraction run so you always work with the current column definitions. Note the schema version (from the changelog/header) in the review report.

---

## Step 1a — Optional: User-Provided Genotype Individual File

If genotype data already exists for this paper, the user may place a `.ind` (EIGENSTRAT) or `.fam` (PLINK) file in `input/`. If present, read it first:

- `.ind` format: whitespace-separated, one row per individual: `Individual_ID  Sex  Group_Name` (Sex coded as `M`/`F`/`U`)
- `.fam` format: whitespace-separated, six columns per individual: `Family_ID  Individual_ID  Paternal_ID  Maternal_ID  Sex  Phenotype` (Sex coded `1`=male, `2`=female, `0`=unknown)

If this file is present:
- Use it as the **authoritative list of individuals and row order** — it defines which individuals are in the package and how many rows the `.janno` should have. Treat it as guiding the granularity of what constitutes a "sample" in the Poseidon sense.
- Treat this file as a shortcut for Step 2 (Sample Identification) — you already know who the individuals are and how many there should be; your job becomes filling in the remaining metadata from the paper, not discovering the sample list from scratch.
- If the paper's text or supplementary tables mention individuals NOT present in this file, flag this clearly in the review report rather than silently adding or dropping rows.
- **Correct the `.ind`/`.fam` file if the paper provides better information for two fields:**
  1. **Sex coded as `U`/`0` (unknown):** If the paper's supplementary tables provide a clear genetic sex determination (`M`/`F`), override the `U` in the file with the correct value. Write the corrected `.ind`/`.fam` back to `input/` (overwriting in place) and use the corrected sex in `Genetic_Sex` in the `.janno`. Log the change in `corrections_log.md`.
  2. **Individual IDs that differ only by punctuation from the paper's canonical IDs** (e.g. `OAK003B` in the file vs. `OAK003.B` in the paper's tables): correct the ID in the `.ind`/`.fam` to match the paper exactly. Use the corrected ID as `Poseidon_ID` in the `.janno`. Log the change in `corrections_log.md`. Do not rename IDs for any other reason without flagging it in the review report.

If this file is absent, proceed to Step 1 and identify individuals from the paper itself (Step 2).

---

## Step 1 — Ingest

Given a paper folder (e.g. `papers/Author2024/`), identify all input files:

- **Main paper**: any `.pdf` in `input/` that is not obviously a supplement
- **Supplementary PDF**: any `.pdf` with "supp", "supplement", "SI", or "table" in the filename
- **Excel attachments**: any `.xlsx` or `.xls` in `input/`

Use the following tools for extraction:
- PDF text and tables → `pdfplumber` (preferred) or `pymupdf`
- Excel files → `pandas` with `openpyxl` engine

Install dependencies if needed:
```bash
pip install pdfplumber pymupdf pandas openpyxl
```

Extract:
1. Full text of the main paper (especially Methods, Results, Supplementary Data references)
2. All tables from the supplementary PDF, preserving headers
3. All sheets from any Excel attachments

Save raw extracted content to `output/raw_extraction.txt` for debugging.

---

## Step 2 — Sample Identification

Before filling any columns, reason carefully about what constitutes a "sample" in this paper:

- Ancient DNA papers often report multiple **individuals**, each of which may have multiple **libraries**. The `.janno` file is at the **individual level** (one row per individual, i.e. per `Poseidon_ID`).
- Look for a primary sample table — usually in the supplementary material — listing all individuals with identifiers, site, country, and dating.
- Cross-reference with the main text to catch any samples mentioned there but absent from tables.
- Watch for samples that are re-analysed from prior publications (they may need a different `Publication` entry).

Write a brief summary of what you found to `output/review_report.md` before proceeding.

---

## Step 3 — Field Extraction

For each identified individual, extract as many janno fields as the paper provides. Below are the most important fields grouped by category. Use `n/a` for any field that cannot be determined.

### Mandatory (must be present for every row)

| Column | Notes |
|--------|-------|
| `Poseidon_ID` | Unique identifier. Use the sample name exactly as in the paper if unambiguous. Follow the convention `SiteAbbrev_Period_Number` if the paper uses it. Must be unique within the package. |
| `Group_Name` | Population/group label as used in the paper. May contain multiple values separated by `;`. |
| `Genetic_Sex` | `Female`, `Male`, or `Unknown` only. |

### Spatiotemporal provenance

| Column | Notes |
|--------|-------|
| `Country` | Modern country name in English. |
| `Country_ISO` | ISO 3166-1 alpha-3 code (e.g. `DEU`, `TUR`). |
| `Location` | Site name or region. Use the name as given in the paper. |
| `Site` | Specific archaeological site name, if given separately from Location. |
| `Latitude` | Decimal degrees, positive = North. |
| `Longitude` | Decimal degrees, positive = East. |
| `Date_Type` | `C14`, `contextual`, or `modern`. |
| `Date_C14_Labnr` | Lab number(s) for radiocarbon dates, e.g. `OxA-12345`. Semicolon-separated if multiple. |
| `Date_C14_Uncal_BP` | Uncalibrated radiocarbon date in BP. Semicolon-separated if multiple. |
| `Date_C14_Uncal_BP_Err` | Error on uncalibrated date. Semicolon-separated if multiple. |
| `Date_BC_AD_Median` | Median calibrated date as BC/AD integer (negative = BC). |
| `Date_BC_AD_Start` | Start of calibrated date range (2-sigma or as reported). |
| `Date_BC_AD_Stop` | End of calibrated date range. |
| `Date_Note` | Free text — record exactly what date information was available, e.g. "calibrated with OxCal 4.4, IntCal20, 2σ range". |

**Date extraction is the most error-prone step.** Papers report dates in many formats. Always record the original values in `Date_Note` even when you can fill the structured columns.

### Genetic data quality (fill only what is explicitly stated in the paper)

| Column | Notes |
|--------|-------|
| `Capture_Type` | `Shotgun`, `1240K`, `ArborComplete`, `ArborPrimePlus`, `TwistAncientDNA`, `OtherCapture`, or `ReferenceGenome`. |
| `Nr_SNPs` | Number of SNPs covered, as integer. |
| `Endogenous` | Fraction of reads mapping to human reference, as decimal 0–1 (not percentage). |
| `Damage` | Fraction of C→T substitutions at 5′ end, as decimal 0–1. |
| `Contamination` | Contamination estimate, as decimal 0–1. |
| `Contamination_Err` | Error on contamination estimate. |
| `Contamination_Meas` | Method used, e.g. `angsd`, `schmutzi`. |

### Biological

| Column | Notes |
|--------|-------|
| `MT_Haplogroup` | Mitochondrial haplogroup as reported. |
| `Y_Haplogroup` | Y-chromosome haplogroup as reported (males only). |
| `Age_Death` | Age at death category: `infant`, `child`, `juvenile`, `subadult`, `adult`, `old adult`, `unknown`. |

### Publication

| Column | Notes |
|--------|-------|
| `Publication` | BibTeX key(s) for the source publication(s). Use `AuthorYEAR` format, e.g. `Müller2024`. Semicolon-separated if multiple. This must match an entry in the `.bib` file. |

---

## Step 3b — SSF (Sequencing Source File) Extraction

The `.ssf` file is **library/sequencing-entity level**, not individual level. One individual (one `Poseidon_ID`) may have several rows in the `.ssf` — one per DNA library or sequencing run. The link between the two files is the `poseidon_IDs` column in the `.ssf`, which must match `Poseidon_ID` values in the `.janno` (many-to-many).

Read `schema/ssf_columns.tsv` for the authoritative column list. Key fields to look for in the paper's Methods and supplementary lab-process tables:

| Column | Notes |
|--------|-------|
| `poseidon_IDs` | One or more `Poseidon_ID` values this sequencing entity belongs to, `;`-separated. |
| `udg` | UDG treatment: `minus`, `half`, `plus`, or `none`. |
| `library_built` | Library protocol: `single`, `double`, or other reported method. |
| `notes` | Free text for anything not captured elsewhere (e.g. enzyme, kit, size selection). |
| `accession_ena` / `accession_sra` | Database accession for raw reads, if deposited (e.g. ENA, SRA). Look in the Data Availability section. |
| `secondary_accession` | Secondary/run-level accession, if separate from the main one. |

**Practical extraction approach:**
- Library-level tables are often in the supplementary material, separate from the sample-level table used for the `.janno`.
- If the paper only reports library counts ("each individual was sequenced from N libraries") without per-library detail, create one `.ssf` row per individual as a simplification and note this limitation explicitly in the review report — do not fabricate distinct library identifiers.
- Accessions are usually listed in a "Data Availability" statement or a dedicated supplementary table; check both.

---

## Step 4 — Extraction Prompt Strategy

When using the Claude API or reasoning about a paper, use this approach:

1. **First pass**: Ask "List all ancient human individuals reported in this paper with their sample IDs, site, country, and any date information."
2. **Second pass**: For each individual, ask "Fill the following Poseidon janno fields for sample X: [field list]. Quote the exact text from the paper that supports each field."
3. **Third pass**: For sequencing/library metadata, ask "List all DNA libraries or sequencing runs for sample X, with UDG treatment, library protocol, and any database accession."
4. **Reconciliation**: If the same sample appears in both the main text and a supplementary table with conflicting values, prefer the supplementary table (it is usually the primary data source) and note the conflict in `Date_Note` or the review report.

---

## Step 5 — Output Formatting

Write four files to `output/`: `AuthorYEAR.janno`, `AuthorYEAR.ssf`, `AuthorYEAR.bib`, and `POSEIDON.yml`.

### `.janno`

- Tab-separated, UTF-8 encoded
- First row is the header with exact column names from the schema
- Only include columns for which at least one sample has a value (omit entirely empty columns)
- Missing values: use empty string (not `NA`, not `NULL`, not `-`)
- List columns (e.g. `Group_Name`, `Date_C14_Labnr`): separate multiple values with `;` (no spaces around semicolon)
- Decimal separator: `.` (period), never comma
- `Poseidon_ID` must be unique within the file
- If a `.ind`/`.fam` file was provided (Step 1a), row order and ID/Sex/Group values must match it exactly

Example first rows:
```
Poseidon_ID	Group_Name	Genetic_Sex	Country	Location	Date_Type	Date_BC_AD_Median	Publication
Site001_BA_I001	Bronze_Age_Bavaria	Male	Germany	Augsburg	C14	-1800	Müller2024
Site001_BA_I002	Bronze_Age_Bavaria	Female	Germany	Augsburg	contextual	-1750	Müller2024
```

### `.ssf`

- Tab-separated, UTF-8 encoded, same formatting conventions as `.janno`
- One row per sequencing entity/library; `poseidon_IDs` column links back to `.janno`'s `Poseidon_ID`
- If library-level detail isn't available, one row per individual is an acceptable fallback — flag this in the review report

### `.bib`

- Standard BibTeX format
- One entry per distinct publication referenced in the `Publication` column of the `.janno`
- Use the same citation key as used in `.janno` (e.g. `Müller2024`)
- Populate `author`, `title`, `journal`, `year`, `doi` from the paper's own metadata (title page, journal website, or CrossRef if needed)

Example:
```bibtex
@article{Müller2024,
  author = {Müller, A. and Schmidt, B.},
  title = {Ancient genomes from Bronze Age Bavaria},
  journal = {Journal of Archaeogenetics},
  year = {2024},
  doi = {10.xxxx/xxxxx}
}
```

### `POSEIDON.yml`

- Defines the package and points to its constituent files (relative paths)
- Genotype data fields (`genotypeData`) should reference filenames the user will supply themselves — use placeholder filenames following the package naming convention (e.g. `AuthorYEAR.bed`/`.bim`/`.fam`) and note in the review report that these files are not created by this process
- Include `poseidonVersion` matching the schema version noted in Step 0

Example:
```yaml
poseidonVersion: 2.7.1
title: AuthorYEAR
contributor:
  - name: "[fill in - not stated in paper]"
packageVersion: 0.1.0
lastModified: 2026-06-22
bibFile: AuthorYEAR.bib
jannoFile: AuthorYEAR.janno
ssfFile: AuthorYEAR.ssf
genotypeData:
  format: EIGENSTRAT
  genoFile: AuthorYEAR.geno
  snpFile: AuthorYEAR.snp
  indFile: AuthorYEAR.ind
```

Flag the `contributor` field and any other fields not derivable from the paper for the user to fill in manually.

---

## Step 6 — Review Report

Write `output/review_report.md` with:

1. **Summary**: how many samples found, how many janno rows, how many ssf rows, Poseidon schema version used
2. **Ambiguities**: fields where you had to make a judgment call — explain your reasoning
3. **Missing fields**: fields you could not fill and why (not in paper, table unclear, etc.)
4. **Conflicts**: any contradictions between main text and supplements
5. **SSF limitations**: note if library-level detail was unavailable and individual-level rows were used as a fallback
6. **Manual fields**: list anything in `POSEIDON.yml` or `.bib` that needs the user's manual input (e.g. `contributor`, missing DOI)
7. **Follow-up questions**: things the user should verify before integrating these files into an archive

---

## General Rules

- **Never invent data.** If a field value is not stated in the paper, leave it empty or `n/a`. Do not infer coordinates from a vague region name without flagging this clearly in the review report.
- **Flag everything uncertain.** Use the review report aggressively — it is cheaper to over-flag than to hand the user wrong data.
- **Prefer the supplement.** Supplementary tables are the authoritative source for sample-level metadata in ancient DNA papers.
- **One row per individual in `.janno`; one row per library/sequencing entity in `.ssf`.**
- **Exact sample IDs.** Use the sample identifiers exactly as given in the paper (or in the user-provided `.ind`/`.fam` file, if present) unless they are ambiguous or non-unique, in which case note your adjustment in the review report.
- **Schema version.** Always note the Poseidon schema version (from the header of `janno_columns.tsv` and `ssf_columns.tsv`) in the review report.
- **No git, no submission.** Never run git commands or attempt to open pull requests. Your job ends when the four output files and the review report are written to `output/`.

---

## Corrections and Durable Rules

Sessions do not share memory with each other — only files on disk persist. Use this convention to handle corrections:

- **Paper-specific fix** (applies only to this paper): correct the file directly and log it in `papers/AuthorYEAR/output/corrections_log.md` with a short rationale.
- **General rule** (should apply to all future papers): ask explicitly to add it to this `CLAUDE.md`, worded generally rather than referencing the specific paper that revealed the issue.
- Periodically review `corrections_log.md` files across papers to spot recurring fixes that should be promoted into a general rule here.

**Who writes `corrections_log.md`:** It is a shared log. Claude writes entries for every correction it applies automatically (e.g. sex fixes, ID renaming). The user writes entries for manual corrections they make after reviewing the output. Both types of entry use the same format: date, what changed, and why.

---

## Quick Start

To process a new paper:

1. Create `papers/AuthorYEAR/input/` and place the PDF (and supplements, and optionally a `.ind`/`.fam` file) inside
2. Tell Claude Code: `"Process papers/AuthorYEAR"`
3. Review `papers/AuthorYEAR/output/review_report.md`
4. Make any corrections to the output files, logging paper-specific ones in `corrections_log.md`
5. Integrate the files into your archive and submit them yourself, however you prefer
