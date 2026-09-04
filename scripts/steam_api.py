import requests


BASE_URL = (
    "https://api.steampowered.com/"
    "ISteamUserStats/GetNumberOfCurrentPlayers/v1/"
)


def get_current_players(appid: int):
    params = {
        "appid": appid
    }

    response = requests.get(
        BASE_URL,
        params=params,
        timeout=15
    )

    response.raise_for_status()

    data = response.json()

    return data["response"].get("player_count")