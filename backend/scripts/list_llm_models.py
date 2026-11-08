"""Liste les modèles accessibles avec la clé LLM de backend/.env.

Usage (depuis le dossier backend, venv actif) :
    python scripts/list_llm_models.py

Affiche uniquement les identifiants de modèles, jamais la clé. Recopie l'un
d'eux dans LLM_MODEL si le fournisseur répond 404.
"""

import sys
from pathlib import Path

import httpx

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from app.core.config import get_settings  # noqa: E402


def main() -> int:
    settings = get_settings()
    key = settings.llm_api_key.get_secret_value() if settings.llm_api_key else ""
    if not key:
        print("LLM_API_KEY est vide dans backend/.env.")
        return 1
    base = settings.llm_base_url.rstrip("/")
    print(f"Fournisseur : {base}  |  modèle actuel : {settings.llm_model}")
    try:
        if "generativelanguage.googleapis.com" in base and not key.startswith("sk-"):
            response = httpx.get(
                f"{base}/models", params={"key": key, "pageSize": 100}, timeout=15
            )
            response.raise_for_status()
            ids = [
                item["name"].removeprefix("models/")
                for item in response.json().get("models", [])
                if "generateContent" in item.get("supportedGenerationMethods", [])
            ]
        else:
            response = httpx.get(
                f"{base}/models",
                headers={"Authorization": f"Bearer {key}"},
                timeout=15,
            )
            response.raise_for_status()
            ids = [item["id"] for item in response.json().get("data", [])]
    except httpx.HTTPStatusError as error:
        print(f"Le fournisseur a répondu HTTP {error.response.status_code}.")
        return 1
    except httpx.HTTPError as error:
        print(f"Connexion impossible ({type(error).__name__}).")
        return 1

    print(f"\n{len(ids)} modèle(s) disponibles :")
    for model_id in sorted(ids):
        marker = "  <-- actuel" if model_id == settings.llm_model else ""
        print(f"  {model_id}{marker}")
    if settings.llm_model not in ids:
        print(f"\nLe modèle « {settings.llm_model} » n'est PAS dans la liste : change LLM_MODEL.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
