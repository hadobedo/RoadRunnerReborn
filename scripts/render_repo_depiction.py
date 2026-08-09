#!/usr/bin/env python3
"""Render a small Sileo/HTML depiction for a package feed."""

import argparse
import html
import json
from pathlib import Path


def arguments():
    parser = argparse.ArgumentParser()
    parser.add_argument("--output-dir", required=True, type=Path)
    parser.add_argument("--package", required=True)
    parser.add_argument("--name", required=True)
    parser.add_argument("--version", required=True)
    parser.add_argument("--summary", required=True)
    parser.add_argument("--compatibility", required=True)
    parser.add_argument("--source-url", required=True)
    parser.add_argument("--page-id", required=True)
    parser.add_argument("--github-repository", required=True)
    return parser.parse_args()


def counters(page_id: str, repository: str) -> tuple[str, str]:
    page = html.escape(page_id, quote=True)
    repo = html.escape(repository, quote=True)
    visits = f"https://visitor-badge.laobi.icu/badge?page_id={page}"
    downloads = f"https://img.shields.io/github/downloads/{repo}/latest/total?label=GitHub%20downloads"
    return visits, downloads


def main():
    args = arguments()
    args.output_dir.mkdir(parents=True, exist_ok=True)
    visits, downloads = counters(args.page_id, args.github_repository)
    source = html.escape(args.source_url, quote=True)
    name = html.escape(args.name)
    package = html.escape(args.package)
    version = html.escape(args.version)
    summary = html.escape(args.summary)
    compatibility = html.escape(args.compatibility)

    depiction = {
        "class": "DepictionTabView",
        "minVersion": "0.3",
        "tabs": [
            {
                "class": "DepictionStackView",
                "tabname": "Details",
                "views": [
                    {"class": "DepictionMarkdownView", "markdown": args.summary, "useSpacing": True},
                    {"class": "DepictionSeparatorView"},
                    {"class": "DepictionHeaderView", "title": "Information"},
                    {"class": "DepictionTableTextView", "title": "Version", "text": args.version},
                    {"class": "DepictionTableTextView", "title": "Compatibility", "text": args.compatibility},
                    {"class": "DepictionTableTextView", "title": "Package ID", "text": args.package},
                    {"class": "DepictionSeparatorView"},
                    {"class": "DepictionHeaderView", "title": "Usage"},
                    {
                        "class": "DepictionMarkdownView",
                        "markdown": f"![Visits]({visits})  ![GitHub downloads]({downloads})",
                        "useSpacing": True,
                    },
                    {"class": "DepictionSeparatorView"},
                    {"class": "DepictionHeaderView", "title": "Links"},
                    {
                        "class": "DepictionTableButtonView",
                        "title": "Source on GitHub",
                        "action": args.source_url,
                        "openExternal": True,
                    },
                ],
            }
        ],
    }
    (args.output_dir / f"{args.package}.json").write_text(
        json.dumps(depiction, indent=2) + "\n", encoding="utf-8"
    )

    html_page = f'''<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <meta name="theme-color" content="#1677ff">
  <title>{name} {version} · Nick's Works</title>
  <style>
    :root {{ color-scheme: dark light; --bg:#101116; --card:#1b1d23; --line:#353943; --text:#f5f7fb; --muted:#a9afbb; --accent:#4d9aff; }}
    * {{ box-sizing:border-box; }}
    body {{ margin:0; background:var(--bg); color:var(--text); font:16px/1.55 -apple-system,BlinkMacSystemFont,"Segoe UI",sans-serif; }}
    main {{ max-width:680px; margin:0 auto; padding:28px 20px 42px; }}
    h1 {{ margin:0; font-size:28px; letter-spacing:-.04em; }}
    .version {{ color:var(--accent); font-size:15px; }}
    .sub {{ margin:3px 0 0; color:var(--muted); }}
    .card {{ margin:16px 0; padding:20px; border:1px solid var(--line); border-radius:18px; background:var(--card); }}
    h2 {{ margin:0 0 10px; font-size:18px; }}
    p {{ color:var(--muted); }}
    .stats {{ display:flex; flex-wrap:wrap; gap:8px; margin-top:14px; }}
    .stats img {{ height:20px; }}
    a {{ color:var(--accent); }}
    footer {{ color:var(--muted); font-size:12px; text-align:center; }}
  </style>
</head>
<body>
  <main>
    <header><h1>{name}</h1><div class="version">Version {version}</div><p class="sub">Nick's Works · {compatibility}</p></header>
    <section class="card"><h2>About</h2><p>{summary}</p>
      <div class="stats"><img src="{visits}" alt="Visits"><img src="{downloads}" alt="GitHub downloads"></div>
    </section>
    <section class="card"><h2>Links</h2><p><a href="{source}" target="_blank" rel="noreferrer">Source on GitHub ↗</a></p></section>
    <footer>{package} · <a href="https://hadobedo.github.io/repo/Packages">APT metadata</a></footer>
  </main>
</body>
</html>
'''
    (args.output_dir / f"{args.package}.html").write_text(html_page, encoding="utf-8")


if __name__ == "__main__":
    main()
