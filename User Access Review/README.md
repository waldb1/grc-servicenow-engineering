A PowerShell automation script that compares Active Directory group membership against an authorized ServiceNow group, flags any user with system access but no corresponding ServiceNow authorization, and automatically opens an incident ticket to remediate the finding.

## The control being tested

A standard access-review question: does everyone who technically has access to a system actually have documented authorization for it? This script automates that comparison instead of a manual, periodic access review spreadsheet.

## What it does

1. Loads credentials from `.env`
2. Authenticates to ServiceNow via OAuth (password grant), native in PowerShell using `Invoke-RestMethod`
3. Pulls ServiceNow group membership for the authorized group
4. Loads AD user data (mock CSV for demo purposes — swap for `Get-ADGroupMember` against a live domain)
5. Uses `Compare-Object` to find users present in AD but missing from the authorized ServiceNow group
6. For each unauthorized user found, automatically creates a ServiceNow incident ticket requesting access removal

## Why `Compare-Object` and `SideIndicator` direction matters

```powershell
$unauthorizedAccess = $comparison | Where-Object { $_.SideIndicator -eq "<=" }
```

`Compare-Object -ReferenceObject $adUsers -DifferenceObject $snowUsers` returns `<=` for items present in the reference list (AD) but missing from the difference list (ServiceNow). Reversing the argument order would flip the meaning of the indicator, so this direction was chosen deliberately, not by default.

## Setup

1. Clone this repo
2. Copy `.env.example` to `.env` and fill in ServiceNow credentials
3. Run:
powershell
.\uar.ps1

## Requirements

- PowerShell 5.1+ or PowerShell 7+
- ServiceNow instance with a Connected App configured for Resource Owner Password Credentials grant

## Known limitations

- AD data is currently mocked via CSV for portfolio/demo purposes; a production version would use `Get-ADGroupMember` against a live domain
- Comparison is name-based in the mock version; a production version should compare on a stable unique identifier (e.g., employee ID) to avoid false positives from name formatting differences
- Auto-remediation (ticket creation) currently fires automatically on any finding; a production deployment should gate this behind a human approval step before taking action against real user access