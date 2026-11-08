import logging
import logging.config


def configure_logging(level: str) -> None:
    logging.config.dictConfig(
        {
            "version": 1,
            "disable_existing_loggers": False,
            "formatters": {
                "standard": {
                    "format": "%(asctime)s %(levelname)s %(name)s: %(message)s",
                },
            },
            "handlers": {
                "console": {
                    "class": "logging.StreamHandler",
                    "formatter": "standard",
                },
            },
            # httpx journalise l'URL complète de chaque requête (INFO), or certains
            # fournisseurs (Gemini, Geoapify) placent la clé API dans l'URL.
            "loggers": {
                "httpx": {"level": "WARNING"},
                "httpcore": {"level": "WARNING"},
            },
            "root": {
                "handlers": ["console"],
                "level": level.upper(),
            },
        }
    )
