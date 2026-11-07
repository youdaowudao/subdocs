#!/usr/bin/env python3
"""Build two internal Windows fixtures differing only in the scrolling CSS.

Both read the owning quick-connect source tree. A Go overlay replaces just
the embedded stylesheet with a historical CSS fixture for the before build;
no second assistant source tree or published executable is modified.
"""
from __future__ import annotations

import hashlib
import importlib.util
import json
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
REPO = ROOT.parents[1]
WORK = ROOT / ".work" / "css-compare"
CSS = ROOT / "frontend" / "style.css"
HISTORICAL_CSS = "5267829:usegoodai-codex-installer/quick-connect/frontend/style.css"


def main() -> None:
    spec = importlib.util.spec_from_file_location("quick_connect_build", ROOT / "build.py")
    build = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(build)
    WORK.mkdir(parents=True, exist_ok=True)
    output = WORK / "builds"
    output.mkdir(exist_ok=True)
    before = subprocess.check_output(["git", "show", HISTORICAL_CSS], cwd=REPO)
    after = CSS.read_bytes()
    if before == after:
        raise SystemExit("The before and after stylesheets are identical.")
    fixture = WORK / "style-before-scroll.css"
    fixture.write_bytes(before)
    overlay = WORK / "before-overlay.json"
    overlay.write_text(json.dumps({"Replace": {str(CSS): str(fixture)}}), encoding="utf-8")

    build.bundle_image_tool("windows-amd64.exe")
    build.bundle_models_script()
    go = build.go_command()
    subprocess.run([go, "run", "./tools/resources", "-icon", "frontend/logo.png", "-out", "rsrc_windows_amd64.syso"],
                   cwd=ROOT, env=build.environment(), check=True)
    records = []
    for name, stylesheet, extra in [("before-css", before, ["-overlay", str(overlay)]), ("after-css", after, [])]:
        target = output / ("helper-" + name + ".exe")
        subprocess.run([go, "build", "-trimpath", "-buildvcs=false", "-tags", build.BUILD_TAGS,
                        *extra, "-ldflags", "-s -w -H windowsgui", "-o", str(target), "."],
                       cwd=ROOT, env=build.environment(GOOS="windows", GOARCH="amd64"), check=True)
        program = target.read_bytes()
        other = after if name == "before-css" else before
        if stylesheet not in program or other in program:
            raise SystemExit(f"{name}: embedded CSS does not match the selected fixture")
        for asset in [ROOT / "frontend" / "app.js", ROOT / "frontend" / "index.html", ROOT / "imagetool" / "program"]:
            if asset.read_bytes() not in program:
                raise SystemExit(f"{name}: missing unchanged asset {asset.name}")
        records.append({"name": name, "exe": str(target), "exe_sha256": hashlib.sha256(program).hexdigest(),
                        "css_sha256": hashlib.sha256(stylesheet).hexdigest(), "size": len(program)})
    report = {"source_commit": subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=REPO, text=True).strip(),
              "historical_css": HISTORICAL_CSS, "builds": records}
    (WORK / "metadata.json").write_text(json.dumps(report, indent=2, ensure_ascii=False), encoding="utf-8")
    print(json.dumps(report, indent=2, ensure_ascii=False))


if __name__ == "__main__":
    main()
