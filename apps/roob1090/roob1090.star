"""
Applet: roob1090
Author: Rob Steilberg
Summary: roob1090 Flight Tracker
Description: Show aircraft flight tracking data from the roob1090 API
"""

load("schema.star", "schema")
load("render.star", "render")
load("http.star", "http")
load("encoding/json.star", "json")

AIRCRAFT_URL = "https://aircraft.robsteilberg.io/airports/boards/%s"
MAX_AGE = 60


def fetch_aircraft_board(icao):
    result = {}
    response = http.get(AIRCRAFT_URL % icao)
    if response.status_code != 200:
        print("Bad response from aircraft.robsteilberg.io: %s" % response.status_code)
        return result
    return json.decode(response.body())


def render_aircraft_board(board):
    row_widgets = []
    # render arrivals
    row_widgets.append(render.Text(
        content="ARRIVALS:",
        color="#F3DC5D"
    ))
    arriving = board["arriving"] + board["arrived"]
    arrivals = []
    for arrival in arriving:
        text = "%s, %s" % (arrival["flight"], arrival["type"])
        if "origin" in arrival:
            text += " from %s" % arrival["origin"]
        arrivals.append(text)
    row_widgets.append(
        render.Marquee(
            width=64,
            child=render.Text("; ".join(arrivals)),
            offset_start=64,
            offset_end=48
        )
    )
    # render departures
    row_widgets.append(render.Text(
        content="DEPARTURES:",
        color="#F3DC5D"
    ))
    departing = board["departing"] + board["departed"]
    departures = []
    for departure in departing:
        text = "%s, %s" % (departure["flight"], departure["type"])
        if "destination" in departure:
            text += " to %s" % departure["destination"]
        departures.append(text)
    row_widgets.append(
        render.Marquee(
            width=64,
            child=render.Text("; ".join(departures)),
            offset_start=64,
            offset_end=48
        )
    )

    return render.Root(
        child=render.Column(row_widgets),
        max_age=MAX_AGE
    )


def main(config):
    board = fetch_aircraft_board("KAUS")
    return render_aircraft_board(board)
