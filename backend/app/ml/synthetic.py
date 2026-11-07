"""Synthetic, fully anonymous training data for M3 experiments.

The generator encodes a plausible (but invented) relationship between study
habits and grades. Models trained on it are labelled ``trained_on="synthetic"``
and must be retrained on real, anonymized, consented data before production
use.
"""

import random

from app.ml.m3_performance import FEATURES


def generate_synthetic_dataset(
    n_samples: int = 2000, seed: int = 42
) -> tuple[list[list[float]], list[float]]:
    rng = random.Random(seed)
    rows: list[list[float]] = []
    targets: list[float] = []
    for _ in range(n_samples):
        avg = rng.gauss(65, 14)
        trend = rng.gauss(0, 3)
        hours = max(0.0, rng.gauss(8, 4))
        completion = min(1.0, max(0.0, rng.gauss(0.7, 0.2)))
        attendance = min(1.0, max(0.5, rng.gauss(0.88, 0.1)))
        difficulty = rng.choice([0.0, 0.1, 0.2, 0.34, 0.5])
        avg = min(100.0, max(0.0, avg))
        target = (
            0.9 * avg
            + 0.6 * trend
            + 0.35 * min(hours, 20)
            + 8 * completion
            + 6 * attendance
            - 4 * difficulty
            + 3
            + rng.gauss(0, 3)
        )
        rows.append([avg, trend, min(hours, 30.0), completion, attendance, difficulty])
        targets.append(min(100.0, max(0.0, target)))
    assert len(rows[0]) == len(FEATURES)
    return rows, targets
