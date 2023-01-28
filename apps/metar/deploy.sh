#!/usr/bin/env zsh
DIR="$(dirname -- "$0")"
"$DIR"/render.sh && pixlet push --installation-id metar "purely-veritable-relieved-duck-e1d" "$DIR"/metar.webp
