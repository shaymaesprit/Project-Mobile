"""Train and version the M3 performance model.

Usage (requires the optional ML dependencies)::

    pip install -e ".[ml]"
    python -m app.ml.train

Trains a Ridge regression on synthetic data, evaluates it on a hold-out split
against the rule-based baseline, and stores a new artifact version only when
it improves on the baseline's MAE.
"""

import argparse
import sys

from app.ml import registry
from app.ml.m3_performance import BASELINE, FEATURES, MODEL_NAME
from app.ml.synthetic import generate_synthetic_dataset


def _baseline_predict(row: list[float]) -> float:
    total = BASELINE["intercept"]
    for coef, mean, value in zip(BASELINE["coef"], BASELINE["means"], row):
        total += coef * (value - mean)
    return min(100.0, max(0.0, total))


def train(n_samples: int = 2000, seed: int = 42, save: bool = True) -> dict:
    try:
        import numpy as np
        from sklearn.linear_model import Ridge
        from sklearn.metrics import mean_absolute_error, r2_score
        from sklearn.model_selection import train_test_split
    except ImportError as error:  # pragma: no cover - depends on environment
        raise SystemExit(
            "scikit-learn is required: pip install -e \".[ml]\""
        ) from error

    rows, targets = generate_synthetic_dataset(n_samples, seed)
    x = np.array(rows)
    y = np.array(targets)
    x_train, x_test, y_train, y_test = train_test_split(
        x, y, test_size=0.2, random_state=seed
    )
    means = x_train.mean(axis=0)
    model = Ridge(alpha=1.0).fit(x_train - means, y_train)
    predictions = np.clip(model.predict(x_test - means), 0, 100)

    metrics = {
        "mae": round(float(mean_absolute_error(y_test, predictions)), 3),
        "r2": round(float(r2_score(y_test, predictions)), 3),
        "baseline_mae": round(
            float(mean_absolute_error(y_test, [_baseline_predict(list(r)) for r in x_test])),
            3,
        ),
        "n_train": int(len(x_train)),
        "n_test": int(len(x_test)),
    }
    artifact = {
        "kind": "ridge",
        "trained_on": "synthetic",
        "features": FEATURES,
        "coef": [round(float(c), 5) for c in model.coef_],
        "means": [round(float(m), 5) for m in means],
        "intercept": round(float(model.intercept_), 5),
        "metrics": metrics,
    }
    improved = metrics["mae"] < metrics["baseline_mae"]
    if save and improved:
        path = registry.save_artifact(MODEL_NAME, artifact)
        artifact["path"] = str(path)
    artifact["saved"] = bool(save and improved)
    return artifact


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--samples", type=int, default=2000)
    parser.add_argument("--seed", type=int, default=42)
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()
    result = train(args.samples, args.seed, save=not args.dry_run)
    print("metrics:", result["metrics"])
    print("saved:", result["saved"], result.get("path", ""))
    return 0


if __name__ == "__main__":
    sys.exit(main())
