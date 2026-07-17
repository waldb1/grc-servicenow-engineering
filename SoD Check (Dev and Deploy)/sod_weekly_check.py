import os
import requests
import dotenv
from dotenv import load_dotenv

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

developers = []
approvers = []

# Pull Developer Group members from ServiceNow
dev_response = requests.get(
    f"{instance_url}/api/now/table/sys_user_grmember",
    headers={
        "Authorization": f"Bearer {token}",
        "Accept": "application/json"
    },
    params={
        "sysparm_query": "group.name=Application Development",
        "sysparm_fields":"user.name,user.sys_id"
    }
)
dev_response.raise_for_status()
dev_group_members = dev_response.json()["result"]


# Pull Approver Group members from ServiceNow
approvers_response = requests.get(
    f"{instance_url}/api/now/table/sys_user_grmember",
    headers={
        "Authorization": f"Bearer {token}",
        "Accept": "application/json"
    },
    params={
        "sysparm_query": "group.name=CAB Approval",
        "sysparm_fields":"user.name,user.sys_id"
    }
)
approvers_response.raise_for_status()
approver_group_members = approvers_response.json()["result"]


for developer in dev_group_members:
    developers.append({
        "Developer_Name": developer["user.name"],
        "Dev_User_ID": developer["user.sys_id"]   
    })

for approver in approver_group_members:
    approvers.append({
        "Approver_Name": approver["user.name"],
        "Appvr_User_ID": approver["user.sys_id"]   
    })

def sod_check(dev_list, approver_list):
    # 1. Map out all unique Approver User IDs for instant, reliable lookups
    approver_ids = {appvr["Appvr_User_ID"] for appvr in approver_list if "Appvr_User_ID" in appvr}
    
    conflict_found = False
    
    # 2. Loop through devs and check if their Dev_User_ID matches an approver ID
    for dev in dev_list:
        dev_id = dev.get("Dev_User_ID")
        
        if dev_id in approver_ids:
            print(f"❌ SoD Conflict: {dev['Developer_Name']} (ID: {dev_id}) has both Developer and Approver roles!")
            conflict_found = True
            
    # 3. Print this only once if the whole run is clean
    if not conflict_found:
        print("✅ No SoD conflicts identified.")

# --- Call the function using your existing lists ---
sod_check(developers, approvers)
