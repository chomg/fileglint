#!/usr/bin/env python3
# /// script
# requires-python = ">=3.10"
# dependencies = []
# ///
"""Run project commands and retain evidence for aggregate verification."""

import argparse
from datetime import datetime, timezone
import json
import os
from pathlib import Path
import subprocess
import sys
import uuid

ROOT = Path(__file__).resolve().parents[1]
REQUIRED = ("doctor", "setup", "dev", "check", "test", "test-ui", "build")
AGGREGATES = ("verify", "preflight")
HARNESS_VERSION = "0.2.1"


def load_config():
    config = json.loads((ROOT / "development.json").read_text(encoding="utf-8"))
    if not isinstance(config, dict) or type(config.get("schema_version")) is not int or config["schema_version"] != 2:
        raise ValueError("development.json must be an object with schema_version 2; see the adoption guide for migration.")
    commands = config.get("commands")
    if not isinstance(commands, dict) or any(name not in commands for name in REQUIRED):
        raise ValueError("development.json must define all common command names.")
    for name, command in commands.items():
        if not name or any(c.isspace() for c in name) or name in AGGREGATES:
            raise ValueError("Command names must have no whitespace; verify and preflight are reserved.")
        if command is not None and (
            not isinstance(command, list) or not command
            or any(not isinstance(arg, str) or not arg or "\0" in arg for arg in command)
        ):
            raise ValueError(f"Command {name!r} must be null or a nonempty argument array.")
    scopes = config.get("verification")
    if not isinstance(scopes, dict) or set(scopes) != {"local", "ci"}:
        raise ValueError("Define verification.local and verification.ci in development.json.")
    for scope in ("local", "ci"):
        steps = scopes.get(scope)
        if (not isinstance(steps, list) or not steps
                or any(not isinstance(name, str) or name not in commands or name in {"dev", "setup"} for name in steps)
                or len(set(steps)) != len(steps)):
            raise ValueError(f"verification.{scope} must be a nonempty list of unique finite check names.")
    return config


def git(*args):
    result = subprocess.run(["git", "--no-optional-locks", "-C", str(ROOT), *args],
                            text=True, capture_output=True, check=False)
    if result.returncode:
        raise ValueError("Git state is unavailable; preflight requires a committed project checkout.")
    return result.stdout.strip()


def state_directory():
    try:
        return Path(git("rev-parse", "--absolute-git-dir")) / "ai-dev-harness"
    except (OSError, ValueError):
        return ROOT / "artifacts" / "harness"


def working_state():
    try:
        return {"commit": git("rev-parse", "--verify", "HEAD"),
                "dirty": bool(git("status", "--porcelain", "--untracked-files=all"))}
    except (OSError, ValueError):
        return {"commit": None, "dirty": None}


def exit_status(code):
    return code if code >= 0 else 128 - code


def run_step(command, log):
    process = subprocess.Popen(command, cwd=ROOT, stdout=subprocess.PIPE,
                               stderr=subprocess.STDOUT, text=True, errors="replace")
    try:
        for line in process.stdout:
            log.write(line)
            log.flush()
            print(line, end="", flush=True)
        return exit_status(process.wait())
    except KeyboardInterrupt:
        process.terminate()
        try:
            process.wait(timeout=5)
        except subprocess.TimeoutExpired:
            process.kill()
            process.wait()
        raise
    finally:
        process.stdout.close()


def aggregate(config, kind, scope):
    state = state_directory()
    state.mkdir(parents=True, exist_ok=True)
    lock = state / "verification.lock"
    try:
        lock.mkdir()
    except FileExistsError:
        raise ValueError(f"Verification already locked: {lock}. Confirm its owner stopped before removing a stale lock.")
    run = None
    report = None
    try:
        (lock / "owner.json").write_text(json.dumps({"pid": os.getpid(), "kind": kind}), encoding="utf-8")
        run_id = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ-") + uuid.uuid4().hex[:8]
        run = state / "runs" / run_id
        run.mkdir(parents=True)
        report = {"schema_version": 1, "harness_version": HARNESS_VERSION, "kind": kind,
                  "scope": scope, "started_at": datetime.now(timezone.utc).isoformat(),
                  "starting_state": working_state(), "steps": [], "result": "blocked"}
        if kind == "preflight":
            if report["starting_state"]["commit"] is None:
                raise ValueError("Commit the configured project before automated execution.")
            if report["starting_state"]["dirty"]:
                raise ValueError("Preflight requires a clean worktree. Preserve and commit intentional changes first.")
        steps = list(config["verification"][scope])
        if kind == "preflight":
            steps = ["doctor", *[name for name in steps if name != "doctor"]]
        for index, name in enumerate(steps, start=1):
            command = config["commands"][name]
            # Log names are based on sequence, never on a custom command name or path.
            logfile = f"{index:02d}.log"
            entry = {"command": name, "exit_code": 2, "log": logfile}
            report["steps"].append(entry)
            with (run / logfile).open("w", encoding="utf-8") as log:
                if command is None:
                    log.write(f"NOT CONFIGURED: {name}\n")
                    print(f"NOT CONFIGURED: {name}", file=sys.stderr)
                    code = 2
                else:
                    print(f"[{kind}:{scope}] {name}", flush=True)
                    try:
                        code = run_step(command, log)
                    except OSError as error:
                        log.write(f"Cannot execute {name}: {error}\n")
                        print(f"Cannot execute {name}: {error}", file=sys.stderr)
                        code = 2
            entry["exit_code"] = code
            if code:
                report["result"] = "failed"
                return code
        report["result"] = "passed"
        return 0
    except KeyboardInterrupt:
        if report is not None:
            report["result"] = "interrupted"
        return 130
    except (OSError, ValueError) as error:
        if report is not None:
            report["error"] = str(error)
        print(f"Cannot complete {kind}: {error}", file=sys.stderr)
        return 2
    finally:
        try:
            if report is not None and run is not None:
                report["finished_at"] = datetime.now(timezone.utc).isoformat()
                report["ending_state"] = working_state()
                (run / "run.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
                print(f"Evidence: {run}", flush=True)
        finally:
            (lock / "owner.json").unlink(missing_ok=True)
            lock.rmdir()


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("command", nargs="?")
    parser.add_argument("--list", action="store_true", help="Inspect configuration; does not run checks.")
    parser.add_argument("arguments", nargs=argparse.REMAINDER)
    args = parser.parse_args(argv)
    try:
        config = load_config()
        commands = config["commands"]
        if args.list:
            for name, command in commands.items():
                print(f"{name}: {'configured' if command else 'NOT CONFIGURED'}")
            for scope, steps in config["verification"].items():
                print(f"verify --scope {scope}: {', '.join(steps)} (not executed)")
            print("preflight: clean committed worktree + doctor + selected verification")
            return 0
        if args.command is None:
            parser.error("choose a command or use --list")
        extra = args.arguments[1:] if args.arguments[:1] == ["--"] else args.arguments
        if args.command in AGGREGATES:
            options = argparse.ArgumentParser(prog=f"dev.py {args.command}")
            options.add_argument("--scope", choices=("local", "ci"), default="local")
            return aggregate(config, args.command, options.parse_args(extra).scope)
        if args.command not in commands:
            raise ValueError(f"Unknown command: {args.command}")
        command = commands[args.command]
        if command is None:
            print(f"NOT CONFIGURED: {args.command}. Complete docs/tasks/0001-bootstrap.md.", file=sys.stderr)
            return 2
        return exit_status(subprocess.run(command + extra, cwd=ROOT, check=False).returncode)
    except (OSError, ValueError) as error:
        print(f"Cannot run project command: {error}", file=sys.stderr)
        return 2
    except KeyboardInterrupt:
        return 130


if __name__ == "__main__":
    raise SystemExit(main())
