import json
import os
import urllib.parse
import urllib.request
from datetime import datetime, timezone
from pathlib import Path

API_KEY = os.environ["TICKETMASTER_API_KEY"]

BASE_URL = "https://app.ticketmaster.com/discovery/v2/events.json"
OUTPUT = Path("web/events.json")

events = []
page = 0

while page < 5:
    params = urllib.parse.urlencode({
        "apikey": API_KEY,
        "city": "Berlin",
        "countryCode": "DE",
        "size": 200,
        "page": page,
        "sort": "date,asc",
    })

    request = urllib.request.Request(
        f"{BASE_URL}?{params}",
        headers={"Accept": "application/json"},
    )

    with urllib.request.urlopen(request, timeout=30) as response:
        data = json.load(response)

    batch = data.get("_embedded", {}).get("events", [])

    for event in batch:
        venue = (
            event.get("_embedded", {})
            .get("venues", [{}])[0]
        )

        location = venue.get("location", {})
        start = event.get("dates", {}).get("start", {})

        events.append({
            "id": event.get("id"),
            "name": event.get("name"),
            "date": start.get("localDate"),
            "time": start.get("localTime"),
            "venue": venue.get("name"),
            "latitude": location.get("latitude"),
            "longitude": location.get("longitude"),
            "url": event.get("url"),
        })

    total_pages = data.get("page", {}).get("totalPages", 0)

    if page + 1 >= total_pages:
        break

    page += 1

OUTPUT.parent.mkdir(parents=True, exist_ok=True)

OUTPUT.write_text(
    json.dumps({
        "updatedAt": datetime.now(timezone.utc).isoformat(),
        "events": events,
    }, ensure_ascii=False, indent=2),
    encoding="utf-8",
)

print(f"Saved {len(events)} Berlin events to {OUTPUT}")
