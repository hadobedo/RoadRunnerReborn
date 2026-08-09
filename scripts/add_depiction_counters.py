#!/usr/bin/env python3
"""Add external visit/download counters to existing feed depictions."""

import argparse
import html
import json
from pathlib import Path


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--json", type=Path, required=True)
    parser.add_argument("--html", type=Path, required=True)
    parser.add_argument("--page-id", required=True)
    parser.add_argument("--github-repository", required=True)
    args = parser.parse_args()

    visits = f"https://visitor-badge.laobi.icu/badge?page_id={html.escape(args.page_id, quote=True)}"
    downloads = f"https://img.shields.io/github/downloads/{html.escape(args.github_repository, quote=True)}/latest/total?label=GitHub%20downloads"
    markdown = f"![Visits]({visits})  ![GitHub downloads]({downloads})"

    depiction = json.loads(args.json.read_text(encoding="utf-8"))
    details = depiction.get("tabs", [])[0]
    views = details.setdefault("views", [])
    if not any(view.get("title") == "Usage" for view in views if isinstance(view, dict)):
        views.extend([
            {"class": "DepictionSeparatorView"},
            {"class": "DepictionHeaderView", "title": "Usage"},
            {"class": "DepictionMarkdownView", "markdown": markdown, "useSpacing": True},
        ])
    args.json.write_text(json.dumps(depiction, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")

    page = f'''\n    <section class="card"><h2>Usage</h2><div style="display:flex;gap:8px;flex-wrap:wrap;"><img src="{visits}" alt="Visits"><img src="{downloads}" alt="GitHub downloads"></div></section>'''
    page_html = args.html.read_text(encoding="utf-8")
    if "visitor-badge.laobi.icu" not in page_html:
        page_html = page_html.replace("\n    <footer>", page + "\n    <footer>", 1)
    args.html.write_text(page_html, encoding="utf-8")


if __name__ == "__main__":
    main()
