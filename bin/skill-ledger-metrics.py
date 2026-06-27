#!/usr/bin/env python3
"""Compute MACP skill-evolution metrics from SKILLS.md."""

from __future__ import annotations

import argparse
import json
import sys
from collections import Counter, defaultdict
from dataclasses import dataclass
from pathlib import Path
from typing import Iterable


LEDGER_START = "```skill-ledger"
LEDGER_END = "```"

COVERED_EVENTS = {"created", "reused", "evolved", "evaluated"}
GAP_EVENTS = {"needed", "missing", "none", "retired"}
VALID_EVENTS = COVERED_EVENTS | GAP_EVENTS
VALID_EVAL_TYPES = {"none", "smoke", "virtual", "final", "holdout", "manual"}


@dataclass(frozen=True)
class Entry:
    task_id: str
    skill_id: str
    event: str
    eval_type: str
    eval_score: float | None
    baseline_score: float | None
    verifier_coverage: float | None
    cost_tokens: int | None
    cost_minutes: float | None
    evidence: str
    git_commit: str


def parse_score(raw: str) -> float | None:
    value = raw.strip()
    if value in {"", "-", "na", "n/a", "none"}:
        return None
    if value.endswith("%"):
        return float(value[:-1]) / 100.0
    score = float(value)
    if score > 1.0:
        return score / 100.0
    return score


def parse_int(raw: str) -> int | None:
    value = raw.strip()
    if value in {"", "-", "na", "n/a", "none"}:
        return None
    return int(value)


def parse_float(raw: str) -> float | None:
    value = raw.strip()
    if value in {"", "-", "na", "n/a", "none"}:
        return None
    return float(value)


def ledger_lines(path: Path) -> Iterable[tuple[int, str]]:
    in_block = False
    for lineno, line in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
        stripped = line.strip()
        if not in_block:
            if stripped == LEDGER_START:
                in_block = True
            continue
        if stripped == LEDGER_END:
            return
        yield lineno, line


def parse_entries(path: Path) -> list[Entry]:
    entries: list[Entry] = []
    errors: list[str] = []
    text = path.read_text(encoding="utf-8")
    if LEDGER_START not in {line.strip() for line in text.splitlines()}:
        raise SystemExit(f"{path}: missing ```skill-ledger block")

    for lineno, line in ledger_lines(path):
        stripped = line.strip()
        if not stripped or stripped.startswith("#"):
            continue
        parts = line.split("\t")
        if len(parts) != 11:
            errors.append(f"{path}:{lineno}: expected 11 tab-separated fields, got {len(parts)}")
            continue
        (
            task_id,
            skill_id,
            event,
            eval_type,
            eval_score,
            baseline_score,
            verifier_coverage,
            cost_tokens,
            cost_minutes,
            evidence,
            git_commit,
        ) = [part.strip() for part in parts]

        if event not in VALID_EVENTS:
            errors.append(f"{path}:{lineno}: invalid event {event!r}")
        if eval_type not in VALID_EVAL_TYPES:
            errors.append(f"{path}:{lineno}: invalid eval_type {eval_type!r}")
        if event in COVERED_EVENTS and skill_id in {"", "-", "none"}:
            errors.append(f"{path}:{lineno}: covered event requires a real skill_id")

        try:
            entry = Entry(
                task_id=task_id,
                skill_id=skill_id,
                event=event,
                eval_type=eval_type,
                eval_score=parse_score(eval_score),
                baseline_score=parse_score(baseline_score),
                verifier_coverage=parse_score(verifier_coverage),
                cost_tokens=parse_int(cost_tokens),
                cost_minutes=parse_float(cost_minutes),
                evidence=evidence,
                git_commit=git_commit,
            )
        except ValueError as exc:
            errors.append(f"{path}:{lineno}: invalid numeric field: {exc}")
            continue
        for name, score in (
            ("eval_score", entry.eval_score),
            ("baseline_score", entry.baseline_score),
            ("verifier_coverage", entry.verifier_coverage),
        ):
            if score is not None and not 0.0 <= score <= 1.0:
                errors.append(f"{path}:{lineno}: {name} must be within 0..1")
        entries.append(entry)

    if errors:
        for error in errors:
            print(error, file=sys.stderr)
        raise SystemExit(2)
    return entries


def avg(values: Iterable[float]) -> float | None:
    vals = list(values)
    if not vals:
        return None
    return sum(vals) / len(vals)


def pct(value: float | None) -> str:
    if value is None:
        return "n/a"
    return f"{value * 100:.1f}%"


def summarize(entries: list[Entry]) -> dict[str, object]:
    latest_by_task: dict[str, Entry] = {}
    for entry in entries:
        latest_by_task[entry.task_id] = entry

    covered_tasks = [
        task for task, entry in latest_by_task.items()
        if entry.event in COVERED_EVENTS and entry.skill_id not in {"", "-", "none"}
    ]
    gap_tasks = [
        task for task, entry in latest_by_task.items()
        if task not in covered_tasks and entry.event in GAP_EVENTS
    ]

    eval_scores: dict[str, list[float]] = defaultdict(list)
    lifts: dict[str, list[float]] = defaultdict(list)
    for entry in entries:
        if entry.eval_score is not None:
            eval_scores[entry.eval_type].append(entry.eval_score)
        if entry.eval_score is not None and entry.baseline_score is not None:
            lifts[entry.eval_type].append(entry.eval_score - entry.baseline_score)

    skill_ids = {
        entry.skill_id for entry in entries
        if entry.skill_id not in {"", "-", "none"}
    }
    total_cost_tokens = sum(entry.cost_tokens or 0 for entry in entries)
    total_cost_minutes = sum(entry.cost_minutes or 0 for entry in entries)

    task_count = len(latest_by_task)
    coverage = (len(covered_tasks) / task_count) if task_count else None

    return {
        "entries": len(entries),
        "tasks": task_count,
        "skills": len(skill_ids),
        "skill_coverage": coverage,
        "covered_tasks": len(covered_tasks),
        "open_skill_gaps": len(gap_tasks),
        "events": dict(Counter(entry.event for entry in entries)),
        "eval_counts": dict(Counter(entry.eval_type for entry in entries)),
        "average_eval_score": {
            kind: avg(scores) for kind, scores in sorted(eval_scores.items())
        },
        "average_lift": {
            kind: avg(scores) for kind, scores in sorted(lifts.items())
        },
        "average_verifier_coverage": avg(
            entry.verifier_coverage
            for entry in entries
            if entry.verifier_coverage is not None
        ),
        "cost_tokens": total_cost_tokens,
        "cost_minutes": total_cost_minutes,
    }


def print_text(summary: dict[str, object]) -> None:
    print("MACP skill-evolution metrics")
    print(f"entries: {summary['entries']}")
    print(f"tasks: {summary['tasks']}")
    print(f"skills: {summary['skills']}")
    print(
        "skill coverage: "
        f"{summary['covered_tasks']}/{summary['tasks']} "
        f"({pct(summary['skill_coverage'])})"
    )
    print(f"open skill gaps: {summary['open_skill_gaps']}")

    print("\nevents:")
    events = summary["events"]
    if isinstance(events, dict) and events:
        for event, count in sorted(events.items()):
            print(f"  {event}: {count}")
    else:
        print("  none")

    print("\nevaluations:")
    eval_counts = summary["eval_counts"]
    avg_scores = summary["average_eval_score"]
    avg_lifts = summary["average_lift"]
    if isinstance(eval_counts, dict) and eval_counts:
        for kind, count in sorted(eval_counts.items()):
            score = avg_scores.get(kind) if isinstance(avg_scores, dict) else None
            lift = avg_lifts.get(kind) if isinstance(avg_lifts, dict) else None
            print(f"  {kind}: count={count} avg_score={pct(score)} avg_lift={pct(lift)}")
    else:
        print("  none")

    print(f"\naverage verifier coverage: {pct(summary['average_verifier_coverage'])}")
    print(f"cost tokens: {summary['cost_tokens']}")
    print(f"cost minutes: {summary['cost_minutes']}")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("ledger", type=Path, help="Path to SKILLS.md")
    parser.add_argument("--json", action="store_true", help="Emit JSON")
    args = parser.parse_args()

    entries = parse_entries(args.ledger)
    summary = summarize(entries)
    if args.json:
        print(json.dumps(summary, indent=2, sort_keys=True))
    else:
        print_text(summary)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
