#!/bin/bash
set -euo pipefail

if [ $# -eq 0 ]; then
  echo "Usage: $0 <version>"
  exit 1
fi

version=$1

(cd docker/agent-docker/ && ./build.sh "$version")
(cd docker/agent-docker/ && ./push.sh "$version")

(cd docker/server-docker/ && ./build.sh "$version")
(cd docker/server-docker/ && ./push.sh "$version")
