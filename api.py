from fastapi import FastAPI

from scripts.collect_snapshot import collect_snapshot


app = FastAPI(
    title="Steam Gacha Monitor API",
    description="API for triggering Steam player activity collection",
    version="1.0.0",
)


@app.get("/")
def root():
    return {
        "status": "running",
        "service": "Steam Gacha Monitor API",
    }


@app.post("/collect")
def collect():
    collect_snapshot()

    return {
        "status": "success",
        "message": "Steam snapshot collected",
    }