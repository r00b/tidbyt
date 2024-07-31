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
load("encoding/base64.star", "base64")

AIRPORT = "KAUS"
AIRPORT_BOARD_API_URL = "https://aircraft.robsteilberg.com/airports/boards/%s"

MAX_AGE = 60
ICON_SIZE = 7
MARQUEE_SPEED = 30  # lower = faster

LANDING_ICON = base64.decode("""
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
""")

TAKEOFF_ICON = base64.decode("""
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
""")


def fetch_aircraft_board(icao):
    result = {}
    response = http.get(AIRPORT_BOARD_API_URL % icao)
    if response.status_code != 200:
        print("Bad response from aircraft.robsteilberg.com: %s" % response.status_code)
        return result
    return json.decode(response.body())


def render_aircraft_board(board):
    row_widgets = []
    # render arrivals
    arrivals = get_if_present(board, "arriving", []) + get_if_present(board, "arrived", [])
    row_widgets.append(
        render.Padding(
            pad=(0, 1, 0, 0),
            child=render.Row([
                render_icon(LANDING_ICON),
                render_header("ARRIVALS", len(arrivals))
            ])
        )
    )
    arrivals_text = []
    for arrival in arrivals:
        text = flight_text(arrival, "origin")
        if text:
            arrivals_text.append(text)
    row_widgets.append(render_flight_text(arrivals_text))
    # render departures
    departures = get_if_present(board, "departing", []) + get_if_present(board, "departed", [])
    row_widgets.append(render.Row([
        render_icon(TAKEOFF_ICON),
        render_header("DEPARTURES", len(departures))
    ]))
    departures_texts = []
    for departure in departures:
        text = flight_text(departure, "destination")
        if text:
            departures_texts.append(text)
    row_widgets.append(render_flight_text(departures_texts))
    return render.Root(
        child=render.Column(row_widgets),
        max_age=MAX_AGE,
        delay=MARQUEE_SPEED
    )


def render_icon(image):
    return render.Padding(
        pad=(1, 0, 1, 0),
        child=render.Image(
            src=image,
            width=ICON_SIZE,
            height=ICON_SIZE
        )
    )


def render_header(text, count):
    return render.Padding(
        pad=(0, 1, 0, 0),
        child=render.Row([
            render.Text(
                content="%s:" % text,
                font="tom-thumb",
                color="#F3DC5D"
            ),
            render.Text(
                content="%s" % count,
                font="tom-thumb"
            )
        ])
    )


def flight_text(aircraft, location_key):
    # callsign
    text = get_if_present(aircraft, "flight")
    if not text:
        return None
    # type
    aircraft_type = get_if_present(aircraft, "type")
    if aircraft_type:
        text += ", %s" % aircraft_type
    # origin or destination
    location = get_if_present(aircraft, location_key)
    if location:
        verb = "to" if location_key == "destination" else "from"
        text += " %s %s" % (verb, location)
    return text


def render_flight_text(texts):
    joined_text = "; ".join(texts)
    pad = 0 if len(joined_text) > 12 else 1
    return render.Padding(
        pad=(pad, 0, 0, 0),
        child=render.Marquee(
            width=64,
            child=render.Text(joined_text),
            offset_start=64
        )
    )


def get_if_present(dict, key, fallback=None):
    return dict[key] if key in dict else fallback


def get_schema():
    return schema.Schema(
        version="1",
        fields=[],
    )


def main(config):
    board = fetch_aircraft_board(AIRPORT)
    return render_aircraft_board(board)
