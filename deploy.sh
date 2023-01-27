#!/usr/bin/env zsh
pixlet render metar-roob/metar.star icao=KAUS,KEDC,MHRO,KSAT,KDCA && pixlet push --installation-id metar "purely-veritable-relieved-duck-e1d" metar-roob/metar.webp
