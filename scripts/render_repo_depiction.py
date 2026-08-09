#!/usr/bin/env python3
"""Render the RoadRunner Reborn Sileo and HTML depictions."""

import argparse
import html
import json
import re
from pathlib import Path

ABOUT_MARKDOWN = """Hey! I’ve updated RoadRunner by the Henriksson Brothers for modern rootless/roothide jailbreaks.

**RoadRunner Reborn** makes your Now Playing app (and optionally other selected apps) stay alive through sbreload and resprings, keeping your music and other apps uninterrupted!

Must-have tweak for me back in the rootful days :)

Tested on iOS 15 - 17 rootless, **should** work on rootHide and iOS 18 and newer (fingers crossed)

Submitted an application to host this on the Havoc repo, will update post/leave comment if/when approved!

In the meantime..."""

AT_A_GLANCE = [
    "Supports iOS 15-17 rootless & roothide (arm64 & arm64e)",
    "iPhone 13 Pro Max, iOS 15.4.1 (rootless)",
    "iPhone 14 Pro Max, iOS 16.4 (rootless)",
    "iPhone 13 Pro, iOS 17.1.1 (rootless)",
]

LINKS = [
    ("Repo", "https://hadobedo.github.io/repo"),
    (".deb Releases", "https://github.com/hadobedo/RoadRunnerReborn/releases"),
    ("Source", "https://github.com/hadobedo/RoadRunnerReborn"),
]


def arguments():
    parser = argparse.ArgumentParser()
    parser.add_argument("--output-dir", required=True, type=Path)
    parser.add_argument("--package", required=True)
    parser.add_argument("--name", required=True)
    parser.add_argument("--version", required=True)
    parser.add_argument("--page-id", required=True)
    parser.add_argument("--github-repository", required=True)
    return parser.parse_args()


def counters(page_id: str, repository: str) -> tuple[str, str]:
    page = html.escape(page_id, quote=True)
    repo = html.escape(repository, quote=True)
    visits = f"https://visitor-badge.laobi.icu/badge?page_id={page}"
    downloads = f"https://img.shields.io/github/downloads/{repo}/latest/total?label=GitHub%20downloads"
    return visits, downloads


def markdown_inline(value: str) -> str:
    rendered = html.escape(value, quote=False)
    rendered = re.sub(r"\*\*(.+?)\*\*", r"<strong>\1</strong>", rendered)
    rendered = re.sub(r"`([^`]+)`", r"<code>\1</code>", rendered)
    return rendered


def html_paragraphs(markdown: str) -> str:
    return "\n".join(
        f"      <p>{markdown_inline(paragraph)}</p>"
        for paragraph in markdown.split("\n\n")
    )


def markdown_list(entries: list[str]) -> str:
    return "\n".join(f"- {entry}" for entry in entries)


def html_list(entries: list[str]) -> str:
    return "\n".join(
        f"          <li>{markdown_inline(entry)}</li>" for entry in entries
    )


def sileo_button(title: str, action: str) -> dict[str, str]:
    return {
        "class": "DepictionTableButtonView",
        "title": title,
        "action": action,
        "openExternal": True,
    }


def render_sileo(version: str, package: str, visits: str, downloads: str) -> dict:
    info_views: list[dict] = [
        {
            "class": "DepictionMarkdownView",
            "markdown": ABOUT_MARKDOWN,
            "useSpacing": True,
        },
        {"class": "DepictionSeparatorView"},
        {"class": "DepictionHeaderView", "title": "Information"},
        {"class": "DepictionTableTextView", "title": "Version", "text": version},
        {
            "class": "DepictionTableTextView",
            "title": "Compatibility",
            "text": AT_A_GLANCE[0],
        },
        {"class": "DepictionTableTextView", "title": "Package ID", "text": package},
        {"class": "DepictionSeparatorView"},
        {"class": "DepictionHeaderView", "title": "Links"},
    ]
    info_views.extend(sileo_button(title, url) for title, url in LINKS)
    info_views.extend(
        [
            {"class": "DepictionSeparatorView"},
            {"class": "DepictionHeaderView", "title": "At a glance"},
            {
                "class": "DepictionMarkdownView",
                "markdown": markdown_list(AT_A_GLANCE),
                "useSpacing": True,
            },
            {"class": "DepictionSeparatorView"},
            {"class": "DepictionHeaderView", "title": "Usage"},
            {
                "class": "DepictionMarkdownView",
                "markdown": f"![Visits]({visits})  ![GitHub downloads]({downloads})",
                "useSpacing": True,
            },
        ]
    )
    return {
        "class": "DepictionTabView",
        "minVersion": "0.3",
        "tintColor": "#4D9AFF",
        "tabs": [
            {
                "class": "DepictionStackView",
                "tabname": "Details",
                "views": info_views,
            }
        ],
    }


def render_html(name: str, version: str, package: str, base_url: str, visits: str, downloads: str) -> str:
    links = "\n".join(
        f'<a href="{html.escape(url, quote=True)}" target="_blank" rel="noreferrer">'
        f"{html.escape(title)} <span>↗</span></a>"
        for title, url in LINKS
    )
    glance = html_list(AT_A_GLANCE)
    about = html_paragraphs(ABOUT_MARKDOWN)
    source = html.escape(base_url, quote=True)
    return f'''<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <meta name="theme-color" content="#4D9AFF">
  <title>{html.escape(name)} {html.escape(version)} · Nick's Works</title>
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
    ul {{ margin:8px 0 0; padding-left:22px; color:var(--muted); }}
    li {{ margin:7px 0; }}
    .links {{ display:grid; grid-template-columns:repeat(2,minmax(0,1fr)); gap:9px; }}
    .links a {{ padding:10px 12px; border:1px solid var(--line); border-radius:10px; color:var(--text); text-decoration:none; }}
    .links span {{ float:right; color:var(--accent); }}
    .stats {{ display:flex; flex-wrap:wrap; gap:8px; margin-top:14px; }}
    .stats img {{ height:20px; }}
    a {{ color:var(--accent); }}
    footer {{ color:var(--muted); font-size:12px; text-align:center; }}
    @media (max-width:480px) {{ .links {{ grid-template-columns:1fr; }} }}
  </style>
</head>
<body>
  <main>
    <header><h1>{html.escape(name)}</h1><div class="version">Version {html.escape(version)}</div><p class="sub">Nick's Works · {html.escape(AT_A_GLANCE[0])}</p></header>
    <section class="card">
      <h2>About</h2>
{about}
    </section>
    <section class="card"><h2>Links</h2><div class="links">{links}</div></section>
    <section class="card"><h2>At a glance</h2><ul>{glance}</ul></section>
    <section class="card"><h2>Usage</h2><div class="stats"><img src="{visits}" alt="Visits"><img src="{downloads}" alt="GitHub downloads"></div></section>
    <footer>{html.escape(package)} · <a href="{source}/Packages">APT metadata</a></footer>
  </main>
</body>
</html>
'''


def main():
    args = arguments()
    args.output_dir.mkdir(parents=True, exist_ok=True)
    visits, downloads = counters(args.page_id, args.github_repository)
    depiction = render_sileo(args.version, args.package, visits, downloads)
    (args.output_dir / f"{args.package}.json").write_text(
        json.dumps(depiction, indent=2, ensure_ascii=False) + "\n", encoding="utf-8"
    )
    html_page = render_html(
        args.name,
        args.version,
        args.package,
        "https://hadobedo.github.io/repo",
        visits,
        downloads,
    )
    (args.output_dir / f"{args.package}.html").write_text(html_page, encoding="utf-8")


if __name__ == "__main__":
    main()
