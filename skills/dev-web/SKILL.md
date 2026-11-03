---
name: dev-web
description: "Web guidance from Oursky's engineering handbook. Use when asking about SEO, URL design, localization, web performance, web navigation, or hreflang."
user-invocable: false
---

<!-- handbook-reviewed: 2b4ec2b12888e9476357b2dbfccfab00d46ad1da -->

## Cache root

CACHE="${HANDBOOK_CACHE_DIR:-${XDG_CACHE_HOME:-$HOME/.cache}/oursky-handbook}"

## Files in this topic

- web/index.md — topic overview table; orient here, then read the relevant file below
- web/localization-react.md — react-intl setup, ICU MessageFormat skeletons, displaying locale names
- web/seo-requirements.md — baseline SEO checklist: PageSpeed, og tags, HTTPS, SSL grade, hreflang, 404
- web/url-design.md — base64url encoding for UUID slugs; why and how to implement
- web/web-navigation-practices.md — page titles, URL slugs, breadcrumbs, modals, search state in URL
- web/web-performance.md — async/defer scripts, parcel code-splitting, CDN, static file serving rules

## How to answer

1. Identify which file(s) cover the question.
2. Read the relevant file(s) in **full** from `$CACHE/dev/guides/web/`.
   Do not paraphrase rules from memory — quote the file.
3. For an exact-string lookup (e.g. a config value, command, or rule):
   `rg -l "search term" "$CACHE/dev/guides/web/"`
4. `historical-archive/` is deprecated; do not cite files from it.
