"""Append-only filesystem adapter for Stage 13 export bundles."""

from __future__ import annotations

import json
from pathlib import Path
from typing import Any, Mapping


def write_new_bundle(
    directory: Path, prefix: str, bundle: Mapping[str, Any]
) -> dict[str, Path]:
    directory.mkdir(parents=True, exist_ok=True)
    paths = {
        "events_jsonl": directory / f"{prefix}.events.jsonl",
        "events_csv": directory / f"{prefix}.events.csv",
        "health_markdown": directory / f"{prefix}.health.md",
        "manifest": directory / f"{prefix}.manifest.json",
    }
    if any(path.exists() for path in paths.values()):
        raise FileExistsError("STAGE13_APPEND_ONLY_CONFLICT")
    values = {
        "events_jsonl": str(bundle["events_jsonl"]),
        "events_csv": str(bundle["events_csv"]),
        "health_markdown": str(bundle["health_markdown"]),
        "manifest": json.dumps(
            bundle["manifest"], indent=2, sort_keys=True, ensure_ascii=False
        )
        + "\n",
    }
    created: list[Path] = []
    try:
        for key, path in paths.items():
            with path.open("x", encoding="utf-8", newline="\n") as stream:
                stream.write(values[key])
            created.append(path)
    except Exception:
        for path in created:
            path.unlink(missing_ok=True)
        raise
    return paths
