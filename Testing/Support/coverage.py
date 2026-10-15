#!/usr/bin/env python3
"""Run native tests and produce fresh LLVM source-coverage reports for libFoundation."""

import argparse
import datetime
import hashlib
import json
import os
from pathlib import Path
import signal
import subprocess
import tempfile
import time


def llvm_tool(compiler, name):
    tool = subprocess.check_output([compiler, "-print-prog-name=" + name], text=True).strip()
    subprocess.run([tool, "--version"], check=True, stdout=subprocess.DEVNULL)
    return tool


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def run_test(binary, log, environment, timeout):
    started = time.monotonic()
    timed_out = False
    with log.open("w") as output:
        process = subprocess.Popen([str(binary)], env=environment, stdout=output,
                                   stderr=subprocess.STDOUT, start_new_session=True)
        try:
            status = process.wait(timeout=timeout)
        except subprocess.TimeoutExpired:
            timed_out = True
            os.killpg(process.pid, signal.SIGKILL)
            status = process.wait()
    return {"binary": str(binary), "sha256": digest(binary), "exit_status": status,
            "timed_out": timed_out, "seconds": time.monotonic() - started, "log": str(log)}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, required=True)
    parser.add_argument("--build-dir", type=Path, required=True)
    parser.add_argument("--compiler", default="clang")
    parser.add_argument("--timeout", type=float, default=120)
    parser.add_argument("binaries", nargs="+", type=Path)
    args = parser.parse_args()
    if args.timeout <= 0:
        parser.error("--timeout must be positive")
    root, build = args.root.resolve(), args.build_dir.resolve()
    library = build / "libFoundation.so"
    binaries = sorted(set(binary.resolve() for binary in args.binaries))
    if not library.is_file() or any(not binary.is_file() for binary in binaries):
        parser.error("build the coverage library and selected test binaries first")
    os.chdir(root)
    cov = llvm_tool(args.compiler, "llvm-cov")
    profdata = llvm_tool(args.compiler, "llvm-profdata")
    reports = build / "reports"
    reports.mkdir(parents=True, exist_ok=True)
    stamp = datetime.datetime.now(datetime.timezone.utc).strftime("%Y%m%dT%H%M%SZ-")
    report = Path(tempfile.mkdtemp(prefix=stamp, dir=reports))
    raw = report / "raw"
    raw.mkdir()
    logs = report / "logs"
    logs.mkdir()
    environment = os.environ.copy()
    # Build ID + module signature separate the executable and DSO; PID separates test processes.
    environment["LLVM_PROFILE_FILE"] = str(raw / "%b-%m-%p.profraw")
    manifest = {
        "created_utc": stamp.rstrip("-"), "library": str(library), "library_sha256": digest(library),
        "compiler": subprocess.check_output([args.compiler, "--version"], text=True),
        "llvm_cov": subprocess.check_output([cov, "--version"], text=True),
        "llvm_profdata": subprocess.check_output([profdata, "--version"], text=True),
        "profile_pattern": environment["LLVM_PROFILE_FILE"], "tests": [], "status": "running",
        "scope": "Instrumented Foundation library and its headers; excludes tests, assembly, and external runtimes.",
    }
    manifest_path = report / "manifest.json"
    manifest_path.write_text(json.dumps(manifest, indent=2) + "\n")
    try:
        for binary in binaries:
            label = binary.relative_to(build).as_posix()
            result = run_test(binary, logs / (label.replace("/", "-") + ".log"), environment, args.timeout)
            manifest["tests"].append(result)
            print(f"{label}: {'PASS' if result['exit_status'] == 0 else 'FAIL'}", flush=True)
            if result["exit_status"] != 0:
                print(Path(result["log"]).read_text()[-6000:], flush=True)
        profiles = sorted(raw.glob("*.profraw"))
        if not profiles:
            raise RuntimeError("no raw profiles were produced; check that this is a coverage build")
        indexed = report / "coverage.profdata"
        subprocess.run([profdata, "merge", "-sparse", *map(str, profiles), "-o", str(indexed)], check=True)
        common = [str(library), "-instr-profile=" + str(indexed),
                  "-ignore-filename-regex=(^/usr/|/Testing/)"]
        for command, filename, options in [
            ("report", "report.txt", []),
            ("export", "coverage.json", []),
            ("export", "coverage.lcov", ["-format=lcov"]),
        ]:
            with (report / filename).open("w") as output:
                subprocess.run([cov, command, *common, *options], check=True, stdout=output)
        subprocess.run([cov, "show", *common, "-format=html", "-output-dir=" + str(report / "html"),
                        "-show-line-counts-or-regions", "-show-branches=count", "-show-expansions"], check=True)
        exported = json.loads((report / "coverage.json").read_text())
        sources = {entry["filename"] for unit in exported["data"] for entry in unit["files"]}
        manifest["source_sha256"] = {name: digest(Path(name)) for name in sorted(sources) if Path(name).is_file()}
        manifest["status"] = "passed" if all(test["exit_status"] == 0 for test in manifest["tests"]) else "tests-failed"
        # Never replace an existing directory or discard earlier runs; only update our convenience symlink.
        latest = reports / "latest"
        temporary = report / "latest-link"
        temporary.symlink_to(report.name, target_is_directory=True)
        temporary.replace(latest)
        print(f"Coverage: {report / 'html/index.html'}", flush=True)
        print(f"Summary:  {report / 'report.txt'}", flush=True)
        print(f"Status:   {manifest['status']}", flush=True)
        return 0 if manifest["status"] == "passed" else 1
    except (OSError, RuntimeError, subprocess.SubprocessError) as error:
        manifest["status"] = "report-failed"
        manifest["error"] = str(error)
        print(f"Coverage failed: {error}; details in {report}", flush=True)
        return 1
    finally:
        manifest_path.write_text(json.dumps(manifest, indent=2) + "\n")


if __name__ == "__main__":
    raise SystemExit(main())
