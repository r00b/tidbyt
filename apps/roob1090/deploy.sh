#!/usr/bin/env zsh
DIR="$(dirname -- "$0")"
"$DIR"/render.sh && pixlet push --installation-id roob1090 "joyfully-factual-avid-tench-e04" "$DIR"/roob1090.webp && pixlet push --installation-id roob1090 "venally-credible-superb-finch-fa1" "$DIR"/roob1090.webp
