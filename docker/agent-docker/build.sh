#!/bin/bash

if [ $# -eq 0 ]; then
  echo "Usage: $0 <version>"
  exit 1
fi

version=$1

script -q /dev/null docker build \
  -t dbmarlin/dbmarlin-agent:$version \
  --build-arg VERSION=$version \
  -f Dockerfile \
  . | tee build.log