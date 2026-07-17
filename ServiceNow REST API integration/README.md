A Python script that authenticates to ServiceNow via OAuth (Resource Owner Password Credentials grant) and pulls priority-1 incident records using the Table API.

## What it does

- Authenticates against a ServiceNow instance's `/oauth_token.do` endpoint via OAuth password grant
- Queries the `incident` table for open Priority 1 records via `sysparm_query`
- Compares each incident's `opened_at` timestamp against a 3-day SLA threshold
- Flags and reports any Priority 1 incident that has been open longer than 3 days

## Setup

1. Clone this repo
2. Install dependencies:
pip install -r requirements.txt
3. Copy `.env.example` to `.env` and fill in your own ServiceNow credentials:
SNOW_INSTANCE_URL=https://your-instance.service-now.com
SNOW_CLIENT_ID=your_client_id_here
SNOW_CLIENT_SECRET=your_client_secret_here
SNOW_USERNAME=your_username
SNOW_PASSWORD=your_password
4. Run:
python Python_Servicenow_integration.py

## Requirements

- Python 3.10+
- `requests`
- `python-dotenv`

## Notes

- Secrets are loaded from a `.env` file (never committed — see `.gitignore`) using `python-dotenv`.
- Tested against a free ServiceNow Developer Instance (PDI).