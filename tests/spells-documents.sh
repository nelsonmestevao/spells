#!/usr/bin/env bash
# Tests for the spells that read or convert files.
# Run it from anywhere: tests/spells-documents.sh
#
# tests/lib/checks.sh has the helpers: expect, in_dir, with_stand_ins and more.

# Many checks hand a line of shell to `bash -c` in single quotes, so that it
# runs later, inside the check. shellcheck takes that for a mistake.
# shellcheck disable=SC2016

# shellcheck source=tests/lib/checks.sh
source "$(dirname "$0")/lib/checks.sh"

# --- jpg2jxl -----------------------------------------------------------------
mkdir pics
cp "$SPELLS/tests/fixtures/photo.jpg" pics/one.jpg
cp "$SPELLS/tests/fixtures/photo.jpg" "pics/two words.JPEG"

expect "2 converted, 0 skipped, 0 failed" jpg2jxl pics jxl
expect "0 converted, 2 skipped, 0 failed" jpg2jxl pics jxl
echo "not a picture" >notes.txt
expect "is not a .jpg/.jpeg file" jpg2jxl notes.txt

# --- cxls, cdoc, chtml and cpdf ----------------------------------------------
# Each fixture holds the same small report, saved in a different format.
fixtures=$SPELLS/tests/fixtures

expect "│ Ada    │      42 │ 2024-03-01 │" cxls "$fixtures/sample.xlsx"
expect "│ Linus  │     7.5 │ 2025-01-15 │" cxls "$fixtures/sample.xls"
expect "Hello from the second sheet" cxls "$fixtures/sample.ods" --sheet 2
expect $'Scores\nNotes' cxls "$fixtures/sample.xlsx" --list
expect "has no sheet 'Nope'. Its sheets are: Scores, Notes." cxls "$fixtures/sample.xlsx" --sheet Nope
expect "is not a spreadsheet" cxls "$fixtures/sample.pdf"

expect '<h1 id="quarterly-report">Quarterly Report</h1>' cdoc "$fixtures/sample.docx"
# pandoc drops the header row of an .odt table, unless cdoc steps in.
expect "<td>Name</td>" cdoc "$fixtures/sample.odt"
expect "This is a <strong>sample</strong> document" cdoc "$fixtures/sample.doc"
expect "is not a .docx, .odt or .doc file" cdoc "$fixtures/sample.pdf"

# From a pipe, as chtml reads when it gets no file.
doc_as_markdown() { cdoc "$1" | chtml; }

expect "| Ada   | 42    |" chtml "$fixtures/sample.html"
expect "This is a **sample** document with a [link](https://example.com)." doc_as_markdown "$fixtures/sample.docx"
expect "'nope.html' not found" chtml nope.html

expect "## **Highlights**" cpdf "$fixtures/sample.pdf"
expect "|Linus|7|" cpdf "$fixtures/sample.pdf"
expect "is not a PDF file" cpdf "$fixtures/sample.html"

# --- excoveralls-report ------------------------------------------------------
mkdir -p coverage/cover
cat >coverage/cover/excoveralls.html <<'HTML'
<span class="cov high">100.0</span> <a href="#lib/app/a.ex"><span class="dirname">lib/app/</span><span class="basename">a.ex</span></a>
<span class="cov none">0.0</span> <a href="#lib/app/b.ex"><span class="dirname">lib/app/</span><span class="basename">b.ex</span></a>
<span class="cov medium">50.0</span> <a href="#lib/app/orders/c.ex"><span class="dirname">lib/app/orders/</span><span class="basename">c.ex</span></a>
<span class="cov high">80.0</span> <a href="#lib/app_web/live/d.ex"><span class="dirname">lib/app_web/live/</span><span class="basename">d.ex</span></a>
<span class="cov high">90.0</span> <a href="#lib/mix/tasks/e.ex"><span class="dirname">lib/mix/tasks/</span><span class="basename">e.ex</span></a>
HTML

expect "5 files, 64.0% average coverage" in_dir coverage excoveralls-report
expect "lib/app/a.ex,100.0,high" cat coverage/cover/coverage_report.csv
# Files are grouped by the folder under the app's own folder, whatever the
# app is called. The web layer is one group.
expect "| (root) | 2 | 50.0% | 0.0% | 100.0% |" cat coverage/cover/coverage_report.md
expect "| orders/ | 1 | 50.0% |" cat coverage/cover/coverage_report.md
expect "| web/ | 1 | 80.0% |" cat coverage/cover/coverage_report.md
expect "| mix/ | 1 | 90.0% |" cat coverage/cover/coverage_report.md

# --- fulldoctest (only what it would run; the real thing downloads GHC) ------
expect "haskellPackages.doctest --run" fulldoctest --dry-run -p gloss Demo.hs -- --verbose

finish
