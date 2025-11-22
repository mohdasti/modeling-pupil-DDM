#!/usr/bin/env bash

set -euo pipefail

# Required: repo already has remote 'origin' set and you're authenticated.

git add R/audit_design_coding.R || true
git add R/*.R || true
git add reports/*.qmd 2>/dev/null || true
git add output/publish/**/*.csv 2>/dev/null || true
git add output/publish/**/*.txt 2>/dev/null || true
git add output/publish/**/*.md 2>/dev/null || true

git status
git commit -m "DDM Chapter: audit pass + final PPC tables (subject-wise, unconditional, censored) + methods/report scaffolding"

git push origin HEAD


