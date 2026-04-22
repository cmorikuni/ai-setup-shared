#!/usr/bin/env python3
"""
AI Orchestrator — local-LLM code-generation + test loop.

Configuration (edit here or set env vars):
  AI_TEST_CMD   — command to run tests (default: pytest)
  LLM_PROXY_URL — Ollama proxy URL (default: http://localhost:11435/v1/chat/completions)

Models (edit MODELS dict to match your Ollama setup):
  generate  — strong code model for initial generation
  fix[0]    — fast model for trivial fixes
  fix[1]    — strong model for complex fixes
  audit     — cloud escalation via `claude` CLI
"""
import json
import os
import re
import subprocess
import sys
import time
import urllib.request
from pathlib import Path

PROXY_URL = os.environ.get("LLM_PROXY_URL", "http://localhost:11435/v1/chat/completions")
TEST_CMD = os.environ.get("AI_TEST_CMD", "pytest")

# Adjust model names to match what you have in Ollama (`ollama list`)
MODELS = {
    "generate": "qwen3-coder:latest",
    "fix": [
        "mistral-small:24b",
        "qwen3-coder:latest",
    ],
    "audit": "cloud/sonnet",
}

PROMPTS_DIR = Path(__file__).parent / "prompts"
MAX_FIX_ATTEMPTS = 3
TRIVIAL_THRESHOLD_CHARS = 500
TRIVIAL_THRESHOLD_FAILURES = 3

_SKIP_DIRS = {'.git', '__pycache__', '.venv', 'venv', 'node_modules'}


def load_prompt(name: str) -> str:
    return (PROMPTS_DIR / f"{name}.txt").read_text()


def call_local_model(model: str, system: str, user: str) -> str:
    payload = json.dumps({
        "model": model,
        "messages": [
            {"role": "system", "content": system},
            {"role": "user", "content": user},
        ],
        "stream": False,
    }).encode()
    req = urllib.request.Request(PROXY_URL, data=payload, headers={"Content-Type": "application/json"})
    with urllib.request.urlopen(req, timeout=300) as resp:
        return json.loads(resp.read())["choices"][0]["message"]["content"]


def call_cloud_sonnet(system: str, user: str) -> str:
    prompt = f"{system}\n\n{user}"
    result = subprocess.run(
        ["claude", "-p", prompt],
        capture_output=True, text=True, timeout=300,
    )
    if result.returncode != 0:
        raise RuntimeError(f"claude CLI failed: {result.stderr}")
    return result.stdout


def run_tests(cmd: str, cwd: Path) -> tuple[bool, str]:
    result = subprocess.run(
        ["zsh", "-c", f"source ~/.zshrc 2>/dev/null; {cmd}"],
        cwd=cwd, capture_output=True, text=True, timeout=300,
    )
    output = result.stdout + result.stderr
    return result.returncode == 0, output


def is_trivial_failure(error_output: str) -> bool:
    failure_count = error_output.count("FAILED") + error_output.count("Error:")
    return len(error_output) < TRIVIAL_THRESHOLD_CHARS and failure_count < TRIVIAL_THRESHOLD_FAILURES


def log_event(log_path: Path, event: dict) -> None:
    with open(log_path, "a") as f:
        f.write(json.dumps({"ts": time.time(), **event}) + "\n")


def extract_code(response: str) -> str:
    lines = response.strip().splitlines()
    if lines and lines[0].startswith("```"):
        lines = lines[1:]
    if lines and lines[-1].startswith("```"):
        lines = lines[:-1]
    return "\n".join(lines)


# ── patch mode helpers ────────────────────────────────────────────────────────

def get_file_tree(cwd: Path) -> list[Path]:
    result = []
    for p in sorted(cwd.rglob("*.py")):
        if not any(part in _SKIP_DIRS for part in p.parts):
            result.append(p)
    return result


def locate_files(model: str, issue: str, file_tree: list[Path], cwd: Path) -> list[Path]:
    tree_str = "\n".join(str(p.relative_to(cwd)) for p in file_tree)
    response = call_local_model(
        model,
        load_prompt("locate"),
        f"Issue:\n{issue}\n\nFiles:\n{tree_str}",
    )
    located = []
    for line in response.strip().splitlines():
        line = line.strip().lstrip("- ").strip()
        candidate = cwd / line
        if candidate.exists():
            located.append(candidate)
    return located


def format_files(paths: list[Path], cwd: Path) -> str:
    parts = []
    for p in paths:
        rel = p.relative_to(cwd)
        parts.append(f"=== FILE: {rel} ===\n{p.read_text()}\n=== END FILE ===")
    return "\n\n".join(parts)


def extract_patches(response: str) -> dict[str, str]:
    pattern = re.compile(r"=== FILE: (.+?) ===\n(.*?)\n=== END FILE ===", re.DOTALL)
    return {m.group(1).strip(): m.group(2) for m in pattern.finditer(response)}


def apply_patches(patches: dict[str, str], cwd: Path) -> None:
    for rel_path, content in patches.items():
        target = cwd / rel_path
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(content)
        print(f"[orchestrator] patched {rel_path}")


# ── modes ─────────────────────────────────────────────────────────────────────

def generate_main(spec_path: Path, cwd: Path | None = None) -> None:
    cwd = cwd or spec_path.parent
    output_path = cwd / ".ai_output.py"
    log_path = cwd / ".ai_log.jsonl"
    spec = spec_path.read_text()

    print(f"[orchestrator] spec={spec_path.name} test={TEST_CMD}")

    print(f"[orchestrator] generating with {MODELS['generate']}...")
    code = extract_code(call_local_model(
        MODELS["generate"],
        load_prompt("generate"),
        f"Implement the following spec:\n\n{spec}",
    ))
    output_path.write_text(code)
    log_event(log_path, {"phase": "generate", "model": MODELS["generate"]})

    for attempt in range(MAX_FIX_ATTEMPTS):
        passed, test_output = run_tests(TEST_CMD, cwd)
        log_event(log_path, {"phase": "test", "attempt": attempt, "passed": passed, "output": test_output[:500]})

        if passed:
            print(f"[orchestrator] PASS on attempt {attempt + 1}")
            return

        print(f"[orchestrator] attempt {attempt + 1}/{MAX_FIX_ATTEMPTS} failed")
        trivial = is_trivial_failure(test_output)
        fix_model = MODELS["fix"][0] if trivial else MODELS["fix"][1]
        print(f"[orchestrator] fixing with {fix_model} (trivial={trivial})")

        fixed_code = extract_code(call_local_model(
            fix_model,
            load_prompt("fix"),
            (
                f"Current code:\n```python\n{output_path.read_text()}\n```\n\n"
                f"Test failures:\n```\n{test_output}\n```\n\n"
                "Fix the code so the tests pass."
            ),
        ))
        output_path.write_text(fixed_code)
        log_event(log_path, {"phase": "fix", "attempt": attempt, "model": fix_model})

    passed, test_output = run_tests(TEST_CMD, cwd)
    if passed:
        print("[orchestrator] PASS after fix loop")
        return

    print("[orchestrator] escalating to cloud/sonnet...")
    audit_result = call_cloud_sonnet(
        load_prompt("audit"),
        (
            f"Spec:\n{spec}\n\n"
            f"Current code:\n```python\n{output_path.read_text()}\n```\n\n"
            f"Failing tests:\n```\n{test_output}\n```"
        ),
    )
    log_event(log_path, {"phase": "audit", "model": MODELS["audit"], "result": audit_result[:500]})
    print(f"[orchestrator] audit result:\n{audit_result}")


def patch_main(spec_path: Path, cwd: Path | None = None) -> None:
    cwd = cwd or spec_path.parent
    log_path = cwd / ".ai_log.jsonl"
    spec = spec_path.read_text()

    print(f"[orchestrator] PATCH mode spec={spec_path.name} test={TEST_CMD}")

    file_tree = get_file_tree(cwd)
    print(f"[orchestrator] locating files with {MODELS['generate']}...")
    located = locate_files(MODELS["generate"], spec, file_tree, cwd)
    if not located:
        print("[orchestrator] no files located — check your spec or file tree", file=sys.stderr)
        sys.exit(1)
    print(f"[orchestrator] located: {[str(p.relative_to(cwd)) for p in located]}")
    log_event(log_path, {"phase": "locate", "files": [str(p.relative_to(cwd)) for p in located]})

    file_contents = format_files(located, cwd)
    print(f"[orchestrator] patching with {MODELS['generate']}...")
    response = call_local_model(
        MODELS["generate"],
        load_prompt("patch"),
        f"Issue:\n{spec}\n\nFiles:\n{file_contents}",
    )
    patches = extract_patches(response)
    if not patches:
        print("[orchestrator] no patches extracted from model response", file=sys.stderr)
        sys.exit(1)
    apply_patches(patches, cwd)
    log_event(log_path, {"phase": "patch", "model": MODELS["generate"], "files": list(patches.keys())})

    for attempt in range(MAX_FIX_ATTEMPTS):
        passed, test_output = run_tests(TEST_CMD, cwd)
        log_event(log_path, {"phase": "test", "attempt": attempt, "passed": passed, "output": test_output[:500]})

        if passed:
            print(f"[orchestrator] PASS on attempt {attempt + 1}")
            return

        print(f"[orchestrator] attempt {attempt + 1}/{MAX_FIX_ATTEMPTS} failed")
        trivial = is_trivial_failure(test_output)
        fix_model = MODELS["fix"][0] if trivial else MODELS["fix"][1]
        print(f"[orchestrator] fixing with {fix_model} (trivial={trivial})")

        current_paths = [cwd / p for p in patches if (cwd / p).exists()]
        current_contents = format_files(current_paths, cwd)
        response = call_local_model(
            fix_model,
            load_prompt("patch"),
            (
                f"Issue:\n{spec}\n\n"
                f"Current files:\n{current_contents}\n\n"
                f"Test failures:\n{test_output}\n\n"
                "Fix the failures. Output only the files that need changing."
            ),
        )
        new_patches = extract_patches(response)
        apply_patches(new_patches, cwd)
        patches.update(new_patches)
        log_event(log_path, {"phase": "fix", "attempt": attempt, "model": fix_model, "files": list(new_patches.keys())})

    passed, test_output = run_tests(TEST_CMD, cwd)
    if passed:
        print("[orchestrator] PASS after fix loop")
        return

    print("[orchestrator] escalating to cloud/sonnet...")
    current_paths = [cwd / p for p in patches if (cwd / p).exists()]
    current_contents = format_files(current_paths, cwd)
    audit_result = call_cloud_sonnet(
        load_prompt("audit"),
        (
            f"Issue:\n{spec}\n\n"
            f"Current files:\n{current_contents}\n\n"
            f"Failing tests:\n{test_output}"
        ),
    )
    log_event(log_path, {"phase": "audit", "model": MODELS["audit"], "result": audit_result[:500]})
    print(f"[orchestrator] audit result:\n{audit_result}")


def main() -> None:
    args = sys.argv[1:]
    if not args:
        print("Usage: orchestrator.py [--patch] [--cwd <dir>] <spec-file>", file=sys.stderr)
        sys.exit(1)

    cwd_override: Path | None = None
    if "--cwd" in args:
        idx = args.index("--cwd")
        if idx + 1 >= len(args):
            print("--cwd requires a directory argument", file=sys.stderr)
            sys.exit(1)
        cwd_override = Path(args[idx + 1]).resolve()
        args = args[:idx] + args[idx + 2:]

    if args[0] == "--patch":
        if len(args) < 2:
            print("Usage: orchestrator.py --patch [--cwd <dir>] <spec-file>", file=sys.stderr)
            sys.exit(1)
        spec_path = Path(args[1]).resolve()
        if not spec_path.exists():
            print(f"Spec not found: {spec_path}", file=sys.stderr)
            sys.exit(1)
        patch_main(spec_path, cwd_override)
        return

    spec_path = Path(args[0]).resolve()
    if not spec_path.exists():
        print(f"Spec not found: {spec_path}", file=sys.stderr)
        sys.exit(1)
    generate_main(spec_path, cwd_override)


if __name__ == "__main__":
    main()
