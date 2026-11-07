"""Machine-learning and rule-based intelligence for StudyMate.

Pure-Python models (M1-M4) that operate on a ``StudentSnapshot``. They never
touch the database or the network, which keeps them testable and lets the
snapshot builder enforce per-user data isolation in one place.
"""
