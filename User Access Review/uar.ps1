# --- Step 1: Load .env into environment variables ---
Get-Content ".\.env" | ForEach-Object {
    if ($_ -match "^\s*([^#][^=]*)=(.*)$") {
        $name = $matches[1].Trim()
        $value = $matches[2].Trim()
        [System.Environment]::SetEnvironmentVariable($name, $value, "Process")
    }
}

$InstanceUrl  = $env:SNOW_INSTANCE_URL
$ClientId     = $env:SNOW_CLIENT_ID
$ClientSecret = $env:SNOW_CLIENT_SECRET
$Username     = $env:SNOW_USERNAME
$Password     = $env:SNOW_PASSWORD

# --- Step 2: Authenticate and get the access token ---
try {
    $tokenResponse = Invoke-RestMethod -Uri "$InstanceUrl/oauth_token.do" `
        -Method Post `
        -ContentType "application/x-www-form-urlencoded" `
        -Body @{
            grant_type    = "password"
            client_id     = $ClientId
            client_secret = $ClientSecret
            username      = $Username
            password      = $Password
        }
    $token = $tokenResponse.access_token
    Write-Host "Authentication succeeded."
}
catch {
    Write-Host "Authentication failed: $($_.Exception.Message)"
    exit 1
}

# --- Step 3: Pull SNOW group members ---
$headers = @{
    "Authorization" = "Bearer $token"
    "Accept"        = "application/json"
}

try {
    $snowResponse = Invoke-RestMethod -Uri "$InstanceUrl/api/now/table/sys_user_grmember" `
        -Headers $headers `
        -Method Get `
        -Body @{
            sysparm_query  = "group.name=Application Development"
            sysparm_fields = "user.name,user.sys_id"
        }
}
catch {
    Write-Host "Failed to fetch ServiceNow group members: $($_.Exception.Message)"
    exit 1
}

$adUsers = Import-Csv -Path .\mock_ad_users.csv | Select-Object -ExpandProperty Name 

$snowUsers = $snowResponse.result | Select-Object -ExpandProperty user.name

# --- Step 4: Pull caller to be assigned to INC ticket ---

try {
    $assignedCaller = Invoke-RestMethod -Uri "$InstanceUrl/api/now/table/sys_user" `
        -Headers $headers `
        -Method Get `
        -Body @{
            sysparm_query  = "name=Abraham Lincoln"
            sysparm_fields = "sys_id"
        }
    # $assignedCaller | ConvertTo-Json -Depth 5
    $callerId = $assignedCaller.result[0].sys_id
}
catch {
    Write-Host "Failed to fetch assigned caller: $($_.Exception.Message)"
    exit 1
}

# --- Step 5: Run comparison script and create INC ticket(s) if needed ---

try {
    $comparison = Compare-Object -ReferenceObject $adUsers -DifferenceObject $snowUsers

    $unauthorizedAccess = $comparison | Where-Object { $_.SideIndicator -eq "<=" }

    if ($unauthorizedAccess) {
        Write-Host "SoD/Access Finding: users with AD access NOT authorized in ServiceNow:"
        $unauthorizedAccess | ForEach-Object {
            Write-Host "  ⚠ $($_.InputObject)"
            $ticketBody = @{
                short_description = "Remove $($_.InputObject)'s AD Access Immediately!"
                urgency           = "4"
                impact            = "2"
                comments          = "Please remove $($_.InputObject)'s AD access within 24 hours, as it is inappropriate."
                caller_id         = $callerId
            } | ConvertTo-Json
            try {
                $createINCTicket = Invoke-RestMethod -uri "$InstanceUrl/api/now/table/incident" `
                    -Headers $headers `
                    -Method Post `
                    -ContentType "application/json" `
                    -Body $ticketBody
                Write-Host "All Incident tickets have been created to remove the following users: $($_.InputObject) "
            }
            catch {
                Write-Host "An error has been identified: $($_.Exception.Message)"
                    if ($_.Exception.Response) {
                        $reader = New-Object System.IO.StreamReader($_.Exception.Response.GetResponseStream())
                        $errorBody = $reader.ReadToEnd()
                        Write-Host "ServiceNow error detail: $errorBody"
                    }
                    exit
            }
        }
    } else {
        Write-Host "No unauthorized access found -- all AD users are properly authorized in ServiceNow."
    }
}
catch {
    Write-Host "Comparison failed: $($_.Exception.Message)"
    exit 1
}