import os
import requests
from dotenv import load_dotenv
from datetime import datetime, timedelta

load_dotenv()

instance_url = os.environ["SNOW_INSTANCE_URL"]
client_id = os.environ["SNOW_CLIENT_ID"]
client_secret = os.environ["SNOW_CLIENT_SECRET"]
username = os.environ["SNOW_USERNAME"]
password = os.environ["SNOW_PASSWORD"]

# --- Authenticate ---
token_response = requests.post(
    f"{instance_url}/oauth_token.do",
    data={
        "grant_type": "password",
        "client_id": client_id,
        "client_secret": client_secret,
        "username": username,
        "password": password,
    }
)

token_response.raise_for_status()
token = token_response.json()["access_token"]

# --- Pull priority-1 incidents that are still open ---
# state!=6, state!=7, state!=8, and state!=3 excludes Resolved (6), Closed (7), Canceled (8), and On Hold (3)
response = requests.get(
    f"{instance_url}/api/now/table/incident",
    headers={
        "Authorization": f"Bearer {token}",
        "Accept": "application/json"
    },
    params={
        "sysparm_query": "priority=1^state!=6^state!=7^state!=8^state!=3",
        "sysparm_fields": "number,short_description,opened_at,state"
    }
)
response.raise_for_status()
incidents = response.json()["result"]

# --- SLA check: flag anything open longer than 3 days ---
SLA_LIMIT = timedelta(days=3)
now = datetime.now()
breaches = []

for incident in incidents:
    opened_at = datetime.strptime(incident["opened_at"], "%Y-%m-%d %H:%M:%S")
    age = now - opened_at

    if age > SLA_LIMIT:
        breaches.append({
            "number": incident["number"],
            "short_description": incident["short_description"],
            "opened_at": incident["opened_at"],
            "days_open": age.days
        })

# --- Report ---
print(f"Checked {len(incidents)} open P1 incidents")
print(f"SLA breaches (open > 3 days): {len(breaches)}\n")

for b in breaches:
    print(f"⚠ {b['number']} — {b['short_description']} — open {b['days_open']} days (opened {b['opened_at']})")