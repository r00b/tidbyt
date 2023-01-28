#!/usr/bin/env zsh
DIR="$(dirname -- "$0")"
pixlet render "$DIR"/metar.star icao_primary=KAUS icao_secondary=KDFW,MHRO,KIAH,KDCA
