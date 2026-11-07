"""Convert a Codex rollout JSONL into a readable Markdown transcript.

Codex stores a session as newline-delimited JSON under
``~/.codex/sessions/<year>/<month>/<day>/rollout-*.jsonl``. OpenCode has no
importer for that format, so this produces a plain transcript that can be read
by a human or handed to another agent as context.

Only user and assistant messages are emitted by default; tool calls are large
and noisy, so they are collapsed to one-line summaries unless ``--tools`` is
given.

Usage:
    python export_codex_session.py <rollout.jsonl> -o transcript.md
    python export_codex_session.py --latest -o transcript.md
"""

from __future__ import annotations

import argparse
import json
import sys
from datetime import datetime, timezone
from pathlib import Path

SESSION_ROOT = Path.home() / ".codex" / "sessions"


def latest_rollout() -> Path:
    """Newest rollout file by modification time."""
    candidates = sorted(
        SESSION_ROOT.rglob("rollout-*.jsonl"),
        key=lambda path: path.stat().st_mtime,
        reverse=True,
    )
    if not candidates:
        raise SystemExit(f"No rollout files under {SESSION_ROOT}")
    return candidates[0]


def load_records(path: Path):
    with path.open(encoding="utf-8") as handle:
        for line in handle:
            line = line.strip()
            if not line:
                continue
            try:
                yield json.loads(line)
            except json.JSONDecodeError:
                # A truncated final line is normal for a session still running.
                continue


def message_text(payload: dict) -> str:
    parts = []
    for item in payload.get("content", []):
        if item.get("type") in ("input_text", "output_text", "text"):
            parts.append(item.get("text", ""))
    return "\n\n".join(part for part in parts if part)


def summarise_call(payload: dict) -> str:
    name = payload.get("name", "tool")
    raw = payload.get("arguments") or {}
    try:
        args = json.loads(raw) if isinstance(raw, str) else raw
    except json.JSONDecodeError:
        args = {}
    if isinstance(args, dict):
        detail = args.get("cmd") or args.get("path") or args.get("file_path") or ""
        detail = " ".join(str(detail).split())
        if len(detail) > 160:
            detail = detail[:157] + "..."
        return f"`{name}` {detail}".strip()
    return f"`{name}`"


def flatten_output(output) -> str:
    """Some tool results are a list of content parts rather than plain text."""
    if isinstance(output, str):
        return output
    if isinstance(output, list):
        parts = []
        for item in output:
            if isinstance(item, dict):
                parts.append(str(item.get("text") or item.get("content") or ""))
            else:
                parts.append(str(item))
        return "\n".join(parts)
    return str(output)


def trailing_summary(output, limit: int = 400) -> str:
    """Last few non-empty lines, which is where failures show up."""
    lines = [line.strip() for line in flatten_output(output).splitlines() if line.strip()]
    text = " / ".join(lines[-3:])
    return text[: limit - 3] + "..." if len(text) > limit else text


def convert(path: Path, include_tools: bool) -> str:
    records = list(load_records(path))
    meta = next((r["payload"] for r in records if r.get("type") == "session_meta"), {})

    lines = [
        "# Codex session transcript",
        "",
        f"- Source: `{path}`",
        f"- Session: `{meta.get('session_id', 'unknown')}`",
        f"- Working directory: `{meta.get('cwd', 'unknown')}`",
        f"- Exported: {datetime.now(timezone.utc).isoformat()}",
        "",
        "Tool calls are summarised; the full output stays in the rollout file.",
        "",
        "---",
        "",
    ]

    for record in records:
        if record.get("type") != "response_item":
            continue
        payload = record.get("payload", {})
        kind = payload.get("type")
        timestamp = record.get("timestamp", "")

        if kind == "message":
            role = payload.get("role")
            if role not in ("user", "assistant"):
                continue
            text = message_text(payload).strip()
            if not text:
                continue
            heading = "## User" if role == "user" else "## Assistant"
            lines += [f"{heading}  <sub>{timestamp}</sub>", "", text, ""]

        elif kind == "function_call" and include_tools:
            lines += [f"- {summarise_call(payload)}", ""]

        elif kind == "function_call_output" and include_tools:
            summary = trailing_summary(payload.get("output", ""))
            if summary:
                lines += [f"  - `{summary}`", ""]

    return "\n".join(lines)


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("rollout", nargs="?", help="Path to a rollout JSONL file")
    parser.add_argument("--latest", action="store_true", help="Use the newest rollout")
    parser.add_argument("--tools", action="store_true", help="Include tool calls")
    parser.add_argument("-o", "--output", help="Write here instead of stdout")
    args = parser.parse_args(argv)

    path = latest_rollout() if (args.latest or not args.rollout) else Path(args.rollout)
    if not path.exists():
        print(f"Not found: {path}", file=sys.stderr)
        return 1

    markdown = convert(path, args.tools)
    if args.output:
        output = Path(args.output)
        output.parent.mkdir(parents=True, exist_ok=True)
        output.write_text(markdown, encoding="utf-8", newline="\n")
        print(f"Wrote {args.output} ({len(markdown)} chars)")
    else:
        sys.stdout.reconfigure(encoding="utf-8")
        print(markdown)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())