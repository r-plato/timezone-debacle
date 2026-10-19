# Capture original timezone

$OriginalTimeZone = Get-TimeZone

Write-Host "Original Time Zone:"
Write-Host "  Id: $($OriginalTimeZone.Id)"
Write-Host "  Display Name: $($OriginalTimeZone.DisplayName)"
Write-Host ""

# Time Zone IDs

$BCPrimaryId      = "British Columbia Standard Time"
$BCSecondaryId    = "Yukon Standard Time"

$AlbertaPrimaryId   = "Alberta Standard Time"
$AlbertaSecondaryId = "Canada Central Standard Time"

function Set-PreferredTimeZone {
    param(
        [string]$PrimaryId,
        [string]$SecondaryId
    )

    Write-Host ""
    Write-Host "Attempting to set timezone to '$PrimaryId'..."

    Set-TimeZone -Id $PrimaryId -ErrorAction SilentlyContinue

    $CurrentTimeZone = (Get-TimeZone).Id

    if ($CurrentTimeZone -eq $PrimaryId) {
        Write-Host "Successfully set timezone to '$PrimaryId'"
        return $true
    }

    Write-Host "Primary timezone was not applied."
    Write-Host "Attempting fallback timezone '$SecondaryId'..."

    Set-TimeZone -Id $SecondaryId -ErrorAction SilentlyContinue

    $CurrentTimeZone = (Get-TimeZone).Id

    if ($CurrentTimeZone -eq $SecondaryId) {
        Write-Host "Successfully set timezone to '$SecondaryId'"
        return $true
    }

    Write-Host ""
    Write-Host "ERROR: Unable to set either timezone."
    Write-Host "Current timezone is '$CurrentTimeZone'"

    return $false
}

# Prompt for location

$UserSelectedLocation = Read-Host @"
Select 1 for British Columbia
Select 2 for Alberta

Input
"@

switch ($UserSelectedLocation) {

    '1' {
        $Success = Set-PreferredTimeZone `
            -PrimaryId $BCPrimaryId `
            -SecondaryId $BCSecondaryId
    }

    '2' {
        $Success = Set-PreferredTimeZone `
            -PrimaryId $AlbertaPrimaryId `
            -SecondaryId $AlbertaSecondaryId
    }

    default {
        Write-Host "Invalid selection."
        Read-Host -Prompt "Press Enter to close"
        exit 1
    }
}

if (-not $Success) {
    Read-Host -Prompt "Press Enter to close"
    exit 1
}

# Capture current timezone after change

$CurrentTimeZone = Get-TimeZone

Write-Host ""
Write-Host "================================="
Write-Host "Time Zone Summary"
Write-Host "================================="
Write-Host "Original:"
Write-Host "  Id: $($OriginalTimeZone.Id)"
Write-Host "  Display Name: $($OriginalTimeZone.DisplayName)"
Write-Host ""
Write-Host "Current:"
Write-Host "  Id: $($CurrentTimeZone.Id)"
Write-Host "  Display Name: $($CurrentTimeZone.DisplayName)"
Write-Host "================================="

if ($OriginalTimeZone.Id -ne $CurrentTimeZone.Id) {
    Write-Host "SUCCESS: Time zone changed." -ForegroundColor Green
}
else {
    Write-Host "WARNING: Time zone did not change." -ForegroundColor Yellow
}

# Disable Auto Time Zone Updater

Write-Host ""
Write-Host "Disabling Auto Time Zone Updater..."

Set-Service tzautoupdate -StartupType Disabled -ErrorAction SilentlyContinue
Stop-Service tzautoupdate -ErrorAction SilentlyContinue

$AutoTZService = Get-Service tzautoupdate

Write-Host "tzautoupdate status: $($AutoTZService.Status)"
Write-Host "tzautoupdate startup type: Disabled"

# Configure W32Time triggers

Write-Host ""
Write-Host "Configuring Windows Time Service triggers..."

sc.exe triggerinfo w32time start/networkon stop/networkoff | Out-Null

Write-Host ""
Write-Host "Current W32Time trigger configuration:"
sc.exe qtriggerinfo w32time

# Restart and resync W32Time

Write-Host ""
Write-Host "Restarting Windows Time Service..."

Restart-Service w32time -ErrorAction SilentlyContinue

Write-Host "Forcing time synchronization..."

w32tm /resync

Start-Sleep -Seconds 3

# Verification

Write-Host ""
Write-Host "Verification:"
Write-Host "-------------"

$TimeSource = (w32tm /query /source).Trim()

Write-Host "Time Source: $TimeSource"
Write-Host ""

w32tm /query /status

# Final results

Write-Host ""
Write-Host "================================="
Write-Host "Final Results"
Write-Host "================================="

if ($TimeSource -eq "Local CMOS Clock") {
    Write-Host "WARNING: Device is NOT synchronized with an NTP source." -ForegroundColor Yellow
}
else {
    Write-Host "SUCCESS: Device is synchronized with '$TimeSource'." -ForegroundColor Green
}

Write-Host ""
Write-Host "Current Time Zone:"
Write-Host "  Id: $($CurrentTimeZone.Id)"
Write-Host "  Display Name: $($CurrentTimeZone.DisplayName)"

Write-Host ""
Write-Host "Completed."

Read-Host -Prompt "Verify results and press Enter to close"