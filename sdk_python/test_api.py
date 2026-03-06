#!/usr/bin/env python3
"""Basic API checks for SDK-deployed stack."""

from __future__ import annotations

import argparse
import json
from pathlib import Path

import requests


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Test API for sdk_python deployment")
    parser.add_argument("--state-file", required=True)
    parser.add_argument("--timeout", type=int, default=15)
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    state = json.loads(Path(args.state_file).read_text())
    api_url = state.get("api_url")
    if not api_url:
        raise SystemExit("api_url not found in state file")

    print(f"Testing API URL: {api_url}")

    health = requests.get(f"{api_url}/health", timeout=args.timeout)
    print(f"GET /health -> {health.status_code}")
    print(health.text)

    root = requests.get(api_url, timeout=args.timeout)
    print(f"GET / -> {root.status_code}")
    print(root.text)


if __name__ == "__main__":
    main()
