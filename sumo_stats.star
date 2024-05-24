load("render.star", "render")
load("schema.star", "schema")
load("http.star", "http")
load("math.star", "math")
load("time.star", "time")
load("humanize.star", "humanize")
load('html.star', 'html')

DEFAULT_SUMO = "Ura"
RIKISHI_NAME_URL = "https://sumo-api.com/api/rikishis?shikonaEn="
RIKISHI_BASE_URL = "https://sumo-api.com/api/rikishi"
SUMO_ASSN_RIKISHI_URL = "https://www.sumo.or.jp/EnSumoDataRikishi/profile"
SUMO_ASSN_IMAGE_URL = "https://www.sumo.or.jp/img/sumo_data/rikishi/60x60"
SUMO_INFO_CACHE_SECONDS = 7200
BASHO_URL = "https://sumo-api.com/api/basho/{}"
BASHO_CACHE_SECONDS = 43200

def main(config):
    rikishiName = config.str("sumo_name", DEFAULT_SUMO)
    nameSearchUrl = "{}{}".format(RIKISHI_NAME_URL, rikishiName)
    rikishiNameResponse = http.get(nameSearchUrl, ttl_seconds = SUMO_INFO_CACHE_SECONDS)

    if rikishiNameResponse.status_code != 200:
        errorText = "Sumo API request failed with status {}".format(str(rikishiNameResponse.status_code))
        return render.Root(
            child = render.WrappedText(
                content=errorText,
                width=64,
                color="#fa0",
            )
        )

    nameSearchResults = rikishiNameResponse.json()["records"]

    if nameSearchResults == None:
        errorText = "Could not find rikishi {}".format(rikishiName)
        return render.Root(
            child = render.WrappedText(
                content=errorText,
                width=64,
                color="#fa0",
            )
        )

    baseRikishiInfo = nameSearchResults[0]
    sumoApiId = math.floor(baseRikishiInfo["id"])
    nskId = math.floor(baseRikishiInfo["nskId"])
    name = baseRikishiInfo["shikonaEn"]
    rank = baseRikishiInfo["currentRank"]
    heightCm = math.floor(baseRikishiInfo["height"])
    weightKg = math.floor(baseRikishiInfo["weight"])

    bashoId = humanize.time_format("yyyyMM", time.now())

    matchUrl = "{}/{}/matches?bashoId={}".format(RIKISHI_BASE_URL, sumoApiId, bashoId)
    matchesResponse = http.get(matchUrl, ttl_seconds = SUMO_INFO_CACHE_SECONDS)
    matchResults = []

    if matchesResponse.status_code == 200:
        matchesBody = matchesResponse.json()
        if matchesBody["total"] > 0:
            for match in matchesBody["records"]:
                matchResult = render.Circle(color="#f00", diameter=4, child=render.Circle(color="#000", diameter=2))
                if sumoApiId == match["winnerId"]:
                    matchResult = render.Circle(color="#0f0", diameter=4)
                matchResults.insert(0, render.Padding(pad=(0, 1, 1, 0), child=matchResult))

    nskRikishiUrl = "{}/{}".format(SUMO_ASSN_RIKISHI_URL, nskId)
    nskRikishiResponse = http.get(nskRikishiUrl, ttl_seconds = SUMO_INFO_CACHE_SECONDS)
    nskImage = None

    if nskRikishiResponse.status_code == 200:
        pageBody = html(nskRikishiResponse.body())
        largeImgSrc = pageBody.find("#mainContent > .mdSection1 > .mdColSet1").children_filtered("img").attr("src")
        nskImgId = largeImgSrc[(largeImgSrc.rfind("/") + 1): largeImgSrc.rfind(".jpg")]
        nskSmallImgUrl = "{}/{}.jpg".format(SUMO_ASSN_IMAGE_URL, nskImgId)
        nskImageResponse = http.get(nskSmallImgUrl, ttl_seconds = SUMO_INFO_CACHE_SECONDS)
        print(nskImgId)

        if nskImageResponse.status_code == 200:
            nskImage = render.Image(src=nskImageResponse.body(), width=22, height=22)

    sumoInfoRender = render.Column(
        children = [
            render.Text(content="{} cm".format(heightCm), font="tom-thumb"),
            render.Text(content="{} kg".format(weightKg), font="tom-thumb"),
            render.Row(children = matchResults[0:8]),
            render.Row(children = matchResults[8:14])
        ]
    )

    contentRender = render.Row(
        children = [
            render.Padding(pad=(0, 0, 1, 0), child=nskImage),
            sumoInfoRender
        ]
    )

    pageRender = render.Column(
        children = [
            render.Padding(pad=(0, 0, 0, 1), child=render.Text(name)),
            contentRender
        ]
    )

    return render.Root(
        child = render.Padding(pad=(1, 0, 0, 0), child=pageRender)
    )

def get_schema():
    return schema.Schema(
        version = "1",
        fields = [
            schema.Text(
                id = "sumo_name",
                name = "Sumo Name",
                desc = "The English ring name of the sumo to get data for",
                icon = "user",
            ),
        ],
    )
