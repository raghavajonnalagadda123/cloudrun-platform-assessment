#!/usr/bin/env bash
set -euo pipefail
python -m pip install -r requirements.txt -r requirements-dev.txt
pytest -q
ruff check app tests
docker build --pull -t cloudrun-platform-assessment:local .
echo "Run Trivy separately and retain its output."
