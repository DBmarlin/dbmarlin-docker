#!/bin/bash

if [ $# -eq 0 ]; then
  echo "Usage: $0 <version>"
  exit 1
fi

version=$1

docker run -d -t -i -p 9080:9080 --platform linux/amd64 --env-file .env dbmarlin/dbmarlin-agent:$version