"""Versioned model artifacts stored as JSON files.

Artifacts hold plain coefficients (no pickle), so loading is safe and does not
require scikit-learn at runtime.
"""

import json
import re
from datetime import datetime, timezone
from pathlib import Path

ARTIFACT_DIR = Path(__file__).resolve().parent / "artifacts"
_VERSION_PATTERN = re.compile(r"^v(\d{4})\.json$")


def _model_dir(model_name: str, root: Path | None = None) -> Path:
    return (root or ARTIFACT_DIR) / model_name


def list_versions(model_name: str, root: Path | None = None) -> list[int]:
    directory = _model_dir(model_name, root)
    if not directory.is_dir():
        return []
    versions = []
    for path in directory.iterdir():
        match = _VERSION_PATTERN.match(path.name)
        if match:
            versions.append(int(match.group(1)))
    return sorted(versions)


def save_artifact(model_name: str, payload: dict, root: Path | None = None) -> Path:
    """Writes ``payload`` as the next version and returns its path."""
    directory = _model_dir(model_name, root)
    directory.mkdir(parents=True, exist_ok=True)
    versions = list_versions(model_name, root)
    number = (versions[-1] + 1) if versions else 1
    document = {
        **payload,
        "version": f"{model_name}-v{number:04d}",
        "created_at": datetime.now(timezone.utc).isoformat(),
    }
    path = directory / f"v{number:04d}.json"
    path.write_text(json.dumps(document, indent=2), encoding="utf-8")
    return path


def load_latest(model_name: str, root: Path | None = None) -> dict | None:
    versions = list_versions(model_name, root)
    if not versions:
        return None
    path = _model_dir(model_name, root) / f"v{versions[-1]:04d}.json"
    try:
        document = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, ValueError):
        return None
    required = {"features", "coef", "intercept", "means", "version"}
    if not required <= document.keys():
        return None
    if len(document["coef"]) != len(document["features"]) or len(document["means"]) != len(
        document["features"]
    ):
        return None
    return document
