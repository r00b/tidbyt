#!/usr/bin/env zsh
DIR="$(dirname -- "$0")"
"$DIR"/render.sh && pixlet push --installation-id metar "joyfully-factual-avid-tench-e04" "$DIR"/metar.webp && pixlet push --installation-id metar "venally-credible-superb-finch-fa1" "$DIR"/metar.webp
