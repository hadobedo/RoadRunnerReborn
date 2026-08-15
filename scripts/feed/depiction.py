#!/usr/bin/env python3
"""Depiction tooling for the repo feed.

Subcommands:
  render        Render the Sileo and HTML depictions from the release notes.
  rewrite-dev   Point the dev feed's package index at dev-scoped depictions.
  counters      Add visit/download counters to existing depictions (dotto++).
"""

import argparse
import html
import json
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
from release_notes import validate  # noqa: E402

ABOUT_MARKDOWN = """**RoadRunner Reborn** makes your Now Playing app (and optionally other selected apps) stay alive through sbreload and resprings, keeping your music and other apps uninterrupted!

Tested on iOS 15 - 17 rootless, **should** work on rootHide and iOS 18 and newer (fingers crossed)"""

COMPATIBILITY = "iOS 15+"
FORMATS = "Rootless · RootHide"

LINKS = [
    ("Source on GitHub", "https://github.com/hadobedo/RoadRunnerReborn"),
    ("Support on Ko-fi", "https://ko-fi.com/nicksworks"),
    ("X / Twitter", "https://twitter.com/Nicks_Works"),
    ("Instagram", "https://instagram.com/Nicks_Works"),
    ("YouTube", "https://www.youtube.com/@NicksWorks"),
]

STABLE_PREFIX = "https://hadobedo.github.io/repo/depictions/"
DEV_PREFIX = "https://hadobedo.github.io/repo/dev/depictions/"


def counters(page_id: str, repository: str) -> tuple[str, str]:
    page = html.escape(page_id, quote=True)
    repo = html.escape(repository, quote=True)
    # Cumulative counters. The laobi visitor badge is keyed solely by
    # page_id, which must never change or the count restarts. GitHub
    # /total sums the assets of every release (all versions, rootless +
    # RootHide), unlike /latest/total which only counts the newest one.
    visits = f"https://visitor-badge.laobi.icu/badge?page_id={page}"
    downloads = f"https://img.shields.io/github/downloads/{repo}/total?label=Downloads&color=4d9aff"
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


def clean_list_entries(entries: list[str]) -> list[str]:
    return [entry[2:] if entry.startswith("- ") else entry for entry in entries]


def html_list(entries: list[str]) -> str:
    return "\n".join(
        f"          <li>{markdown_inline(entry)}</li>"
        for entry in clean_list_entries(entries)
    )


def sileo_button(title: str, action: str) -> dict[str, str]:
    return {
        "class": "DepictionTableButtonView",
        "title": title,
        "action": action,
        "openExternal": True,
    }


def render_sileo(version: str, package: str, visits: str, downloads: str, changelog: list[str]) -> dict:
    changelog_entries = clean_list_entries(changelog)
    views: list[dict] = [
        {
            "class": "DepictionMarkdownView",
            "markdown": ABOUT_MARKDOWN,
            "useSpacing": True,
        },
        {"class": "DepictionSeparatorView"},
        {"class": "DepictionHeaderView", "title": "Changelog"},
        {
            "class": "DepictionMarkdownView",
            "markdown": f"**{version}**\n\n{markdown_list(changelog_entries)}",
            "useSpacing": True,
        },
        {"class": "DepictionSeparatorView"},
        {"class": "DepictionHeaderView", "title": "Links"},
    ]
    views.extend(sileo_button(title, url) for title, url in LINKS)
    views.extend(
        [
            {"class": "DepictionSeparatorView"},
            {"class": "DepictionHeaderView", "title": "Information"},
            {"class": "DepictionTableTextView", "title": "Version", "text": version},
            {
                "class": "DepictionTableTextView",
                "title": "Compatibility",
                "text": COMPATIBILITY,
            },
            {"class": "DepictionTableTextView", "title": "Formats", "text": FORMATS},
            {"class": "DepictionTableTextView", "title": "Package ID", "text": package},
            {"class": "DepictionSeparatorView"},
            {"class": "DepictionHeaderView", "title": "Usage"},
            {
                "class": "DepictionMarkdownView",
                "markdown": f"![Visits]({visits})  ![Downloads]({downloads})",
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
                "views": views,
            }
        ],
    }


def render_html(name: str, version: str, package: str, base_url: str, visits: str, downloads: str, changelog: list[str]) -> str:
    links = "\n".join(
        f'<a href="{html.escape(url, quote=True)}" target="_blank" rel="noreferrer">'
        f"{html.escape(title)} <span>↗</span></a>"
        for title, url in LINKS
    )
    changelog = html_list(changelog)
    about = html_paragraphs(ABOUT_MARKDOWN)
    information = html_list([
        f"Version: {html.escape(version)}",
        f"Compatibility: {html.escape(COMPATIBILITY)}",
        f"Formats: {html.escape(FORMATS)}",
        f"Package ID: {html.escape(package)}",
    ])
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
    <header><h1>{html.escape(name)}</h1><div class="version">Version {html.escape(version)}</div><p class="sub">Nick's Works · {html.escape(COMPATIBILITY)}</p></header>
    <section class="card">
      <h2>About</h2>
{about}
    </section>
    <section class="card"><h2>Changelog</h2><p class="version">{html.escape(version)}</p><ul>{changelog}</ul></section>
    <section class="card"><h2>Links</h2><div class="links">{links}</div></section>
    <section class="card"><h2>Information</h2><ul>{information}</ul></section>
    <section class="card"><h2>Usage</h2><div class="stats"><img src="{visits}" alt="Visits"><img src="{downloads}" alt="Downloads"></div></section>
    <footer>{html.escape(package)} · <a href="{source}/Packages">APT metadata</a></footer>
  </main>
</body>
</html>
'''


def cmd_render(args: argparse.Namespace) -> None:
    args.output_dir.mkdir(parents=True, exist_ok=True)
    notes_version, changelog = validate(args.release_notes, args.version)
    visits, downloads = counters(args.page_id, args.github_repository)
    depiction = render_sileo(args.version, args.package, visits, downloads, changelog)
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
        changelog,
    )
    (args.output_dir / f"{args.package}.html").write_text(html_page, encoding="utf-8")


def cmd_rewrite_dev(args: argparse.Namespace) -> None:
    package, packages_path = args.package, Path(args.packages_file)
    blocks = packages_path.read_text(encoding="utf-8").split("\n\n")
    rewritten = []
    for block in blocks:
        if block.startswith("Package: " + package + "\n"):
            block = block.replace(STABLE_PREFIX, DEV_PREFIX)
        rewritten.append(block)
    packages_path.write_text("\n\n".join(rewritten), encoding="utf-8")


def cmd_counters(args: argparse.Namespace) -> None:
    visits, downloads = counters(args.page_id, args.github_repository)
    markdown = f"![Visits]({visits})  ![Downloads]({downloads})"

    depiction = json.loads(Path(args.json).read_text(encoding="utf-8"))
    details = depiction.get("tabs", [])[0]
    views = details.setdefault("views", [])
    if not any(view.get("title") == "Usage" for view in views if isinstance(view, dict)):
        views.extend([
            {"class": "DepictionSeparatorView"},
            {"class": "DepictionHeaderView", "title": "Usage"},
            {"class": "DepictionMarkdownView", "markdown": markdown, "useSpacing": True},
        ])
    Path(args.json).write_text(json.dumps(depiction, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")

    page = f'\n    <section class="card"><h2>Usage</h2><div style="display:flex;gap:8px;flex-wrap:wrap;"><img src="{visits}" alt="Visits"><img src="{downloads}" alt="Downloads"></div></section>'
    page_html = Path(args.html).read_text(encoding="utf-8")
    if "visitor-badge.laobi.icu" not in page_html:
        page_html = page_html.replace("\n    <footer>", page + "\n    <footer>", 1)
    Path(args.html).write_text(page_html, encoding="utf-8")


def main() -> None:
    parser = argparse.ArgumentParser(prog="depiction.py")
    subparsers = parser.add_subparsers(dest="command", required=True)

    render = subparsers.add_parser("render")
    render.add_argument("--output-dir", required=True, type=Path)
    render.add_argument("--package", required=True)
    render.add_argument("--name", required=True)
    render.add_argument("--version", required=True)
    render.add_argument("--page-id", required=True)
    render.add_argument("--github-repository", required=True)
    render.add_argument("--release-notes", type=Path, required=True)
    render.set_defaults(func=cmd_render)

    rewrite = subparsers.add_parser("rewrite-dev")
    rewrite.add_argument("package")
    rewrite.add_argument("packages_file")
    rewrite.set_defaults(func=cmd_rewrite_dev)

    counters_parser = subparsers.add_parser("counters")
    counters_parser.add_argument("--json", type=Path, required=True)
    counters_parser.add_argument("--html", type=Path, required=True)
    counters_parser.add_argument("--page-id", required=True)
    counters_parser.add_argument("--github-repository", required=True)
    counters_parser.set_defaults(func=cmd_counters)

    args = parser.parse_args()
    args.func(args)


if __name__ == "__main__":
    main()
