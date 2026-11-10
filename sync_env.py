#!/usr/bin/env python3
"""Syncs the root .env file into:
1. backend/.env
2. mobile/studymate_app/dart_defines.local.json
"""

import json
import sys
from pathlib import Path

# Ensure utf-8 output on Windows consoles
if sys.platform == "win32":
    try:
        sys.stdout.reconfigure(encoding="utf-8")
    except Exception:
        pass

ROOT = Path(__file__).resolve().parent
ROOT_ENV = ROOT / ".env"
BACKEND_ENV = ROOT / "backend" / ".env"
MOBILE_DART_DEFINES = ROOT / "mobile" / "studymate_app" / "dart_defines.local.json"

DART_DEFINE_KEYS = [
    "STUDYMATE_FIREBASE_API_KEY",
    "STUDYMATE_FIREBASE_APP_ID",
    "STUDYMATE_FIREBASE_PROJECT_ID",
    "STUDYMATE_FIREBASE_SENDER_ID",
    "STUDYMATE_FIREBASE_STORAGE_BUCKET",
    "STUDYMATE_GOOGLE_SERVER_CLIENT_ID",
    "STUDYMATE_API_URL",
    "STUDYMATE_CLOUDINARY_CLOUD_NAME",
    "STUDYMATE_CLOUDINARY_API_KEY",
    "STUDYMATE_CLOUDINARY_API_SECRET",
]

BACKEND_EXCLUDE_PREFIX = "STUDYMATE_"


def parse_env(file_path: Path) -> dict[str, str]:
    env = {}
    if not file_path.exists():
        return env
    with open(file_path, "r", encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith("#") or "=" not in line:
                continue
            key, val = line.split("=", 1)
            env[key.strip()] = val.strip()
    return env


def main():
    if not ROOT_ENV.exists():
        print(f"[-] Aucun fichier .env trouve a la racine ({ROOT_ENV}).")
        print("    Copiez '.env.example' en '.env' et ajoutez vos cles :")
        print("    copy .env.example .env")
        return

    env_vars = parse_env(ROOT_ENV)
    print(f"[OK] {len(env_vars)} variables lues depuis {ROOT_ENV.name}")

    # 1. Update backend/.env
    backend_lines = []
    with open(ROOT_ENV, "r", encoding="utf-8") as f:
        for line in f:
            stripped = line.strip()
            if stripped.startswith("#") or not stripped:
                backend_lines.append(line)
            else:
                key = stripped.split("=")[0].strip()
                if not key.startswith(BACKEND_EXCLUDE_PREFIX):
                    backend_lines.append(line)

    BACKEND_ENV.parent.mkdir(parents=True, exist_ok=True)
    with open(BACKEND_ENV, "w", encoding="utf-8") as f:
        f.writelines(backend_lines)
    print(f"[OK] Backend synchronise -> {BACKEND_ENV.relative_to(ROOT)}")

    # 2. Update mobile/studymate_app/dart_defines.local.json
    dart_defines = {}
    for key in DART_DEFINE_KEYS:
        if key in env_vars:
            dart_defines[key] = env_vars[key]

    MOBILE_DART_DEFINES.parent.mkdir(parents=True, exist_ok=True)
    with open(MOBILE_DART_DEFINES, "w", encoding="utf-8") as f:
        json.dump(dart_defines, f, indent=2, ensure_ascii=False)
    print(f"[OK] Mobile Flutter synchronise -> {MOBILE_DART_DEFINES.relative_to(ROOT)}")

    print("\n[SUCCES] Synchronisation terminee avec succes !")


if __name__ == "__main__":
    main()
