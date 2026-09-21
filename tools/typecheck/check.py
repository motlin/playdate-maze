"""Run LuaLS against game sources, failing on every reported diagnostic."""

import json
from pathlib import Path
import subprocess
import sys

root = Path(__file__).resolve().parents[2]
output = root / "builds" / "luals"
output.mkdir(parents=True, exist_ok=True)
configuration = json.loads((root / ".luarc.json").read_text())
# LuaLS resolves library paths against --check, rather than the configuration file.
configuration["workspace.library"] = [
    str(root / library) for library in configuration["workspace.library"]
]
configuration_path = output / "config.json"
configuration_path.write_text(json.dumps(configuration))
report = output / "report.json"
report.unlink(missing_ok=True)
result = subprocess.run(
    [
        "lua-language-server",
        f"--check={root / 'source'}",
        f"--configpath={configuration_path}",
        f"--logpath={output}",
        f"--metapath={output / 'meta'}",
        "--check_format=json",
        f"--check_out_path={report}",
    ],
    cwd=root,
    check=False,
)
if result.returncode:
    sys.exit(result.returncode)
# Check the report as well as the exit status so warnings cannot pass silently.
diagnostics = json.loads(report.read_text())
if diagnostics:
    print(f"Lua type checking failed; see {report}", file=sys.stderr)
    sys.exit(1)
