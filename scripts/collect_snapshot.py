import csv
from datetime import datetime
from pathlib import Path

from db import get_connection
from scripts.games import GAMES
from scripts.steam_api import get_current_players


DATA_DIR = Path("data")
OUTPUT_FILE = DATA_DIR / "steam_snapshots.csv"


def save_rows_to_db(rows):
    connection = get_connection()

    try:
        with connection.cursor() as cursor:
            insert_query = """
                INSERT INTO steam_player_snapshots (
                    collected_at,
                    appid,
                    name,
                    category,
                    current_players
                )
                VALUES (
                    %s,
                    %s,
                    %s,
                    %s,
                    %s
                )
            """

            for row in rows:
                cursor.execute(
                    insert_query,
                    (
                        row["collected_at"],
                        row["appid"],
                        row["name"],
                        row["category"],
                        row["current_players"],
                    )
                )

        connection.commit()

    finally:
        connection.close()


def collect_snapshot():
    DATA_DIR.mkdir(exist_ok=True)

    collected_at = datetime.now().isoformat(timespec="seconds")

    active_games = [
        game for game in GAMES
        if game["status"] == "active"
    ]

    rows = []

    print(f"Starting collection: {collected_at}")
    print(f"Active games to collect: {len(active_games)}")
    print("-" * 60)

    for game in active_games:
        appid = game["appid"]
        name = game["name"]
        category = game["category"]

        try:
            current_players = get_current_players(appid)

            rows.append({
                "collected_at": collected_at,
                "appid": appid,
                "name": name,
                "category": category,
                "current_players": current_players,
            })

            print(
                f"OK  | {name} | "
                f"{current_players:,} players"
            )

        except Exception as error:
            print(
                f"ERR | {name} | {error}"
            )

    # --------------------------------------------------
    # Save to CSV
    # --------------------------------------------------

    file_exists = OUTPUT_FILE.exists()

    with OUTPUT_FILE.open(
        "a",
        newline="",
        encoding="utf-8"
    ) as file:

        fieldnames = [
            "collected_at",
            "appid",
            "name",
            "category",
            "current_players",
        ]

        writer = csv.DictWriter(
            file,
            fieldnames=fieldnames
        )

        if not file_exists:
            writer.writeheader()

        writer.writerows(rows)

    print("-" * 60)
    print(
        f"Saved {len(rows)} records "
        f"to {OUTPUT_FILE}"
    )

    # --------------------------------------------------
    # Save to PostgreSQL
    # --------------------------------------------------

    save_rows_to_db(rows)

    print(
        f"Saved {len(rows)} records "
        f"to PostgreSQL"
    )


if __name__ == "__main__":
    collect_snapshot()