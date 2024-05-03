"""
Applet: METAR
Author: Rob Steilberg
Summary: METAR aviation weather
Description: Show METAR (aviation weather) text for one primary airport and flight
    category for four secondary airports
"""

load("schema.star", "schema")
load("render.star", "render")
load("http.star", "http")
load("xpath.star", "xpath")
load("re.star", "re")
load("math.star", "math")

WX_URL = "https://www.aviationweather.gov/cgi-bin/data/dataserver.php?dataSource=metars&requestType=retrieve&format=xml&stationString=%s&mostrecentforeachstation=constraint&hoursBeforeNow=2"
DEFAULT_PRIMARY = "KAUS"
DEFAULT_SECONDARY = "KDFW,MHRO,KIAH,KDCA"

MAX_AGE = 60 * 10
MAX_AIRPORT_TTL = 60 * 10
MARQUEE_SPEED = 20  # lower = faster


def fetch_airport_wx(airports):
    result = {}
    response = http.get(WX_URL % airports)
    if response.status_code != 200:
        print("Bad response from aviationweather.gov: %s" % response.status_code)
        return result
    xml = xpath.loads(response.body())
    for airport in airports.split(","):
        result[airport] = parse_airport_wx(xml, airport)
    return result


def parse_airport_wx(xml, airport):
    query_prefix = "/response/data/METAR[station_id='%s']/" % airport
    # extract raw values from XML via XPath
    flight_category = xml.query(query_prefix + "/flight_category")
    altimeter = xml.query(query_prefix + "/altim_in_hg")
    temp = xml.query(query_prefix + "/temp_c")
    dewpoint = xml.query(query_prefix + "/dewpoint_c")
    wind_dir_degrees = xml.query(query_prefix + "/wind_dir_degrees")
    wind_speed_kt = xml.query(query_prefix + "/wind_speed_kt")
    wind_gust_kt = xml.query(query_prefix + "/wind_gust_kt")
    visibility_sm = xml.query(query_prefix + "/visibility_statute_mi")
    # zip up sky coverage with respective bases
    sky_cover = xml.query_all(query_prefix + "/sky_condition/@sky_cover") or []
    cloud_bases = xml.query_all(query_prefix + "/sky_condition/@cloud_base_ft_agl") or []
    sky_condition = []
    for cover, base in zip(sky_cover, cloud_bases):
        # 25000 -> 250; 6500 -> 065; 200 -> 002
        sky_condition.append(cover + left_pad(base[:-2], "0", 3))
    # i.e. TRSA, -BR, +SHRA, etc
    wx = xml.query(query_prefix + "/wx_string")

    return {
        "station_id": airport,
        "flight_category": flight_category,
        "altimeter": apply_if_present(lambda a: round(float(a), 2), altimeter),
        "temp": apply_if_present(round_to_int, temp),
        "dewpoint": apply_if_present(round_to_int, dewpoint),
        "wind_dir_degrees": apply_if_present(parse_wind_direction, wind_dir_degrees),
        "wind_speed_kt": apply_if_present(int, wind_speed_kt),
        "wind_gust_kt": apply_if_present(int, wind_gust_kt),
        "visibility_sm": apply_if_present(parse_visibility_string, visibility_sm),
        "sky_condition": sky_condition,
        "wx": wx
    }


def parse_wind_direction(input):
    if not input:
        return None
    elif not is_numeric_string(str(input)):
        return input
    else:
        return round_to_int(input)


def parse_visibility_string(input):
    if not input:
        return None
    elif input.find("+") != -1:
        return "P" + input.replace("+", "")
    else:
        return round_to_int(input)


def airport_wx_string(airport_wx):
    template = []
    # wind direction and speed with gust if any
    direction = get_if_present(airport_wx, "wind_dir_degrees")
    speed = get_if_present(airport_wx, "wind_speed_kt")
    gust = get_if_present(airport_wx, "wind_gust_kt")
    if direction and speed:
        direction_formatted = left_pad(direction, "0", 3)
        wind = "%s @ %s%sKT" % (direction_formatted, speed, ("G%s" % gust) if gust else "")
        template.append(wind)
    # visibility
    visibility = get_if_present(airport_wx, "visibility_sm")
    if visibility:
        template.append("%sSM" % visibility)
    # sky condition
    sky_conditions = get_if_present(airport_wx, "sky_condition")
    if sky_conditions and len(sky_conditions) > 0:
        template.append(" ".join(sky_conditions))
    # temperature/dewpoint
    temp = get_if_present(airport_wx, "temp")
    dewpoint = get_if_present(airport_wx, "dewpoint")
    if temp and dewpoint:
        template.append("%s/%s" % (temp, dewpoint))
    # altimeter
    altimeter = get_if_present(airport_wx, "altimeter")
    if altimeter:
        template.append("A%s" % right_pad(altimeter, "0", 5))
    # weather
    wx = get_if_present(airport_wx, "wx")
    if wx:
        template.append(wx)
    return " ".join(template)


def render_airports(airport_wx, primary_airport, secondary_airports):
    row_widgets = []
    # primary airport identifier and category
    primary_airport_wx = get_if_present(airport_wx, primary_airport, {})
    primary_flight_category = get_if_present(primary_airport_wx, "flight_category")
    row_widgets.append(
        render.Row([
            render_flight_category(primary_airport, primary_flight_category),
            render.Text(" %s" % primary_flight_category or "", color=color_for_state(primary_flight_category)),
        ])
    )
    # primary airport scrolling wx
    primary_airport_wx_string = airport_wx_string(primary_airport_wx)
    row_widgets.append(
        render.Marquee(
            width=64,
            child=render.Text(primary_airport_wx_string),
            offset_start=64
        )
    )
    # secondary airport flight categories
    secondary_airport_pairs = chunk_list(secondary_airports, 2)
    for [first_icao, second_icao] in secondary_airport_pairs:
        first_airport_wx = get_if_present(airport_wx, first_icao, {"flight_category": None})
        second_airport_wx = get_if_present(airport_wx, second_icao, {"flight_category": None})
        row_widgets.append(
            render.Row(
                [
                    render_flight_category(first_icao, first_airport_wx["flight_category"]),
                    render_flight_category(second_icao, second_airport_wx["flight_category"])
                ],
                cross_align="center",
            ),

        )
    return render.Root(
        child=render.Column(row_widgets),
        max_age=MAX_AGE,
        delay=MARQUEE_SPEED
    )


def render_flight_category(ident, flight_category):
    row = render.Row(
        [
            render.Padding(
                pad=(1, 0, 0, 0),
                child=render.Stack([
                    render.Box(width=24, height=8),
                    render.Padding(
                        pad=(1, 0, 0, 0),
                        child=render.Text(ident)),
                ]),
            ),
            render.Circle(color=color_for_state(flight_category),
                          diameter=6),
        ],
        cross_align="center",
    )
    return row


def color_for_state(flight_category):
    if flight_category == None:
        return "#000000"
    elif flight_category == "VFR":
        return "#00FF00"
    elif flight_category == "IFR":
        return "#FF0000"
    elif flight_category == "MVFR":
        return "#0000FF"
    elif flight_category == "LIFR":
        return "#FF00FF"
    else:
        print("Unknown flight category %s" % flight_category)
        return "#000000"


def chunk_list(items, max_items_per_chunk):
    chunks = []
    for i in range(len(items)):
        chunk_index = math.floor(i / max_items_per_chunk)
        if chunk_index == len(chunks):
            chunks.append([])
        chunks[-1].append(items[i])
    return chunks


# round(29.9269, 2) -> 29.93
def round(num, precision):
    return math.round(num * math.pow(10, precision)) / math.pow(10, precision)


def round_to_int(input):
    return int(round(float(input), 0))


def apply_if_present(fn, arg):
    return fn(arg) if arg else None


def get_if_present(dict, key, fallback=None):
    return dict[key] if key in dict else fallback


def left_pad(value, value_to_pad, desired_len):
    str_value = str(value)
    if len(str_value) >= desired_len:
        return str_value
    else:
        return left_pad(str(value_to_pad) + str_value, value_to_pad, desired_len)


def right_pad(value, value_to_pad, desired_len):
    str_value = str(value)
    if len(str_value) >= desired_len:
        return str_value
    else:
        return right_pad(str_value + str(value_to_pad), value_to_pad, desired_len)


def is_numeric_string(s):
    return bool(re.match(r'^\d+|\.$', s))


def get_schema():
    return schema.Schema(
        version="1",
        fields=[
            schema.Text(
                id="icao_primary",
                name="Primary Airport",
                desc="ICAO of the primary airport",
                icon="plane",
            ),
            schema.Text(
                id="icao_secondary",
                name="Airport(s)",
                desc="Comma-separated list of ICAO airport codes",
                icon="plane",
            ),
        ],
    )


def main(config):
    arg0 = config.get("icao_primary")
    arg1 = config.get("icao_secondary")
    primary_airport = arg0.upper() if arg0 else DEFAULT_PRIMARY
    secondary_airports_str = arg1.upper() if arg1 else DEFAULT_SECONDARY
    secondary_airports = secondary_airports_str.split(",")

    airport_wx = fetch_airport_wx("%s,%s" % (primary_airport, secondary_airports_str))
    return render_airports(airport_wx, primary_airport, secondary_airports)
