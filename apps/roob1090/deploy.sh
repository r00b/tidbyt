#!/usr/bin/env zsh
DIR="$(dirname -- "$0")"
"$DIR"/render.sh && pixlet push --installation-id roob1090 "purely-veritable-relieved-duck-e1d" "$DIR"/roob1090.webp
