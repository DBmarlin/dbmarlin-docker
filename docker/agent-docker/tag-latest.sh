
if [ $# -eq 0 ]; then
  echo "Usage: $0 <version>"
  exit 1
fi

version=$1

docker tag dbmarlin/dbmarlin-agent:$version dbmarlin/dbmarlin-agent:latest