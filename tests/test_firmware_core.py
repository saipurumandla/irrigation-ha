"""The firmware's schedule logic (firmware/irrigation/test_core.cpp), built with g++ and run."""

import shutil
import subprocess
from pathlib import Path

import pytest

SRC = Path(__file__).parent.parent / "firmware" / "irrigation" / "test_core.cpp"


@pytest.mark.skipif(shutil.which("g++") is None, reason="no g++")
def test_schedule_logic(tmp_path):
    exe = tmp_path / "test_core"
    subprocess.run(["g++", "-std=c++17", "-Wall", "-Wextra", "-Werror", "-o", str(exe), str(SRC)], check=True)
    r = subprocess.run([str(exe)], capture_output=True, text=True)
    lines = [line for line in r.stdout.splitlines() if line.startswith(("ok ", "FAIL "))]
    failed = [line for line in lines if line.startswith("FAIL ")]
    assert len(lines) > 50
    assert not failed, "\n".join(failed)
    assert r.returncode == 0
