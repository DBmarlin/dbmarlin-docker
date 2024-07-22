#!/bin/bash

if [ $# -eq 0 ]; then
  echo "Usage: $0 <version>"
  exit 1
fi

version=$1

docker tag dbmarlin/dbmarlin-server:$version localhost:5000/dbmarlin-server:$version
docker push localhost:5000/dbmarlin-server:$version
