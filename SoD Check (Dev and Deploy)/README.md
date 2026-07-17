A Python automation script that checks for Segregation of Duties (SoD) violations by comparing ServiceNow group membership — specifically, flagging any user who belongs to **both** the "Application Development" group and the "CAB Approval" group.

## The control being tested

Segregation of duties is a core internal control: the person who writes/deploys a change should not also be the person who approves it. This script automates that check against live ServiceNow group data instead of a manual, periodic spreadsheet review.

## What it does

1. Authenticates to ServiceNow via OAuth (password grant)
2. Pulls all members of the `Application Development` group
3. Pulls all members of the `CAB Approval` group
4. Cross-references both lists for overlapping users
5. Reports any conflicts found (or confirms none exist)

## Setup

1. Clone this repo
2. Install dependencies:
pip install -r requirements.txt
3. Copy `.env.example` to `.env` and fill in your ServiceNow credentials
4. Run:
python sod_weekly_check.py

## Sample output
❌ SoD Conflict: Bernard Laboy (ID: ee826bf03710200044e0bfc8bcbe5de6) has both Developer and Approver roles!

## Automation / scheduling

This check runs via two PowerShell scripts:

- `automated_batch_job.ps1` — the worker script. Runs the Python check, logs output with timestamps, and generates a SHA-256 hash of each run's log for tamper-evidence (a separate hash file, so a log edited after the fact will no longer match its recorded hash).
- `register_schedule.ps1` — one-time setup. Run this once, as Administrator, to register `automated_batch_job.ps1` as a Windows Scheduled Task that fires weekly (Mondays, 8 AM).

**Setup requires two additional `.env` values** beyond your ServiceNow credentials — see `.env.example`:
- `SOD_PYTHON_EXE` — full path to your Python interpreter
- `SOD_SCRIPT_PATH` — full path to `sod_weekly_check.py`

## Requirements

- Python 3.10+
- `requests`
- `python-dotenv`

## Known limitations

- Comparison is exact-match on user ID (sys_id), not name
- Currently checks two hardcoded groups; a production version would take group names as parameters