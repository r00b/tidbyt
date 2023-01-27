"""
Applet: METAR
Author: Alexander Valys
Summary: METAR aviation weather
Description: Show METAR (aviation weather) text for one airport or flight
    category (VFR/IFR/etc.) for up to 15 airports. Separate airport identifiers
    by commas to display multiple airports.
"""

load("cache.star", "cache")
load("http.star", "http")
load("render.star", "render")
load("schema.star", "schema")

ADDS_URL = "https://www.aviationweather.gov/adds/dataserver_current/httpparam?dataSource=metars&requestType=retrieve&format=csv&stationString=%s&mostrecentforeachstation=constraint&hoursBeforeNow=2"
DEFAULT_AIRPORT = "KJFK, KLGA, KBOS, KDCA, KAUS"

# encryption, schema
# fail expired, add timeout to Root
# play with fonts

MAX_AGE = 60 * 10


def decoded_result_for_airport(airport):
    cache_key = "metar_cache_" + airport
    cached_result = cache.get(cache_key)
    if (cached_result != None):
        result = cached_result
    else:
        rep = http.get(ADDS_URL % airport)
        if rep.status_code != 200:
            return {
                "color": "#000000",
                "text": "Received error %s for %s" % (rep.status_code, airport),
                "flight_category": "ERR",
            }

        result = rep.body()

        cache.set(cache_key, result, ttl_seconds=60)
        # print("fetched for %s" % airport)

    lines = result.strip().split("\n")

    key_line = None
    data_line = None

    for line in lines:
        if line.startswith("raw_text"):
            key_line = line
        elif line.startswith(airport + " "):
            data_line = line

    if data_line == None:
        return {
            "color": "#000000",
            "text": "Invalid airport code %s" % airport,
            "flight_category": "ERR",
        }

    if key_line == None:
        return {
            "color": "#000000",
            "text": "Could not parse METAR",
            "flight_category": "ERR",
        }

    decoded = {"layers": []}

    layers = []
    heights = []

    for label, value in zip(key_line.split(","), data_line.split(",")):
        if label == "sky_cover" and value != "":
            layers.append(value)
        elif label == "cloud_base_ft_agl" and value != "":
            height = value[:-2]
            while len(height) != 3:
                height = "0" + height
            heights.append(height)
        else:
            decoded[label] = value

    sky_condition = zip(layers, heights)
    if len(sky_condition) > 0:
        for layer, height in sky_condition:
            decoded["layers"].append(layer + height)
    else:
        decoded["layers"].append(layers[0])

    altimeter = decoded["altim_in_hg"]
    if len(altimeter) < 5:
        while len(altimeter) != 5:
            altimeter += "0"
    elif len(altimeter) > 5:
        altimeter = altimeter[:5]
    decoded["altim_in_hg"] = altimeter


    if decoded["wind_gust_kt"] != "":
        decoded["wind_speed_kt"] += "G" + decoded["wind_gust_kt"]

    text = decoded["wind_dir_degrees"] \
           + " @ " \
           + decoded["wind_speed_kt"] \
           + "KT " \
           + decoded["visibility_statute_mi"][:-2] \
           + "SM " \
           + decoded["temp_c"][:-2] \
           + "/" \
           + decoded["dewpoint_c"][:-2] \
           + " " \
           + " ".join(decoded["layers"]) \
           + " A" \
           + decoded["altim_in_hg"]

    print(airport + " " + text)
    response = {
        "color": color_for_state(decoded),
        "text": text,
        "flight_category": decoded["flight_category"],
    }

    return response


def color_for_state(result):
    category = result["flight_category"]
    if category == "VFR":
        return "#00FF00"
    elif category == "IFR":
        return "#FF0000"
    elif category == "MVFR":
        return "#0000FF"
    elif category == "LIFR":
        return "#FF00FF"
    elif category == "ERR" or category == "UNK":
        return "#000000"
    else:
        print("Unknown category %s" % category)
        return "#FFFFFF"


def render_single_airport(config, airport):
    use_small_font = config.get("use_small_font") or False

    result = decoded_result_for_airport(airport)
    text = result["text"]
    color = result["color"]

    if use_small_font:
        text_widget = render.WrappedText(
            text,
            color="#FFFFFF",
            font="tom-thumb",
            linespacing=0,
            width=64,
        )

        return render.Root(
            child=render.Column([
                render.Box(height=2, width=64, color=color),
                render.Marquee(
                    text_widget,
                    offset_start=8,
                    offset_end=48,
                    scroll_direction="vertical",
                    height=32,
                ),
            ]),
            delay=200,
            max_age=MAX_AGE,
        )
    else:
        text_widget = render.WrappedText(
            text,
            color="#FFFFFF",
            font="tb-8",
            linespacing=0,
            width=62,
        )

        return render.Root(
            child=render.Row([
                render.Marquee(
                    text_widget,
                    offset_start=8,
                    offset_end=48,
                    scroll_direction="vertical",
                    height=32,
                ),
                render.Box(height=64, width=2, color=color),
            ]),
            delay=200,
            max_age=MAX_AGE,
        )


def render_two_airports(airports):
    row_widgets = []

    first = airports[0]
    result2 = decoded_result_for_airport(first)
    color = result2["color"]
    row_widgets.append(
        render.Row(
            [
                # Create a fixed-width box for the airport code so the
                # flight categories line up
                render.Stack([
                    render.Box(width=24, height=8),
                    render.Text(first.upper() + " "),
                ]),
                render.Circle(color=color, diameter=6),
                render.Text(" %s" % result2["flight_category"], color=color),
            ],
            cross_align="center",
        ),

    )

    metar = render.WrappedText(
        result2["text"],
        color="#FFFFFF",
        font="tom-thumb",
        linespacing=0,
        width=64,
    )
    metar = render.Text(result2["text"])

    row_widgets.append(
        render.Marquee(
            width=64,
            child=metar,
            offset_start=64,
            offset_end=48
        )
    )

    secondary = [[airports[1], airports[2]], [airports[3], airports[4]]]

    for set in secondary:
        first = decoded_result_for_airport(set[0])
        second = decoded_result_for_airport(set[1])
        row_widgets.append(
            render.Row(
                [
                    render_airport(set[0].upper(), first["color"]),
                    render.Text(" "),
                    render_airport(set[1].upper(), second["color"])
                ],
                cross_align="center",
            ),

        )

    return render.Root(
        child=render.Column(row_widgets),
        delay=50,
        max_age=MAX_AGE,
    )

def render_airport(ident, color):
    row = render.Row(
        [
            # Create a fixed-width box for the airport code so the
            # flight categories line up
            render.Stack([
                render.Box(width=24, height=8),
                render.Text(ident),
            ]),
            render.Circle(color=color, diameter=6),
        ],
        cross_align="center",
    )
    return row


def get_schema():
    return schema.Schema(
        version="1",
        fields=[
            schema.Text(
                id="icao",
                name="Airport(s)",
                desc="Comma-separated list of ICAO airport codes. Use just one for METAR text.",
                icon="plane",
            ),
            schema.Toggle(
                id="use_small_font",
                name="Use Small Font",
                desc="When displaying a single airport, use compressed text.",
                icon="compress",
                default=False,
            ),
        ],
    )


def main(config):
    airports = config.get("icao") or DEFAULT_AIRPORT
    airports = airports.upper()
    airports = [a.strip() for a in airports.split(",")]
    return render_two_airports(airports)
