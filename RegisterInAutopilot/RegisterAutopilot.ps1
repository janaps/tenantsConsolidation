<#
    .SYNOPSIS
    RegisterAutopilot.ps1

    .DESCRIPTION
    Registers a device in autopilot using app-credentials. Adds the correct grouptag for the school.
    Uses Get-WindowsAutopilotinfo.ps1 (v 3.6) to do the main work

    .NOTES
    To convert this script to an .exe (ease of use), use following code
    
    Install-Module -Name ps2exe# Convert to EXE
    ps2exe -inputFile "C:\..\RegisterAutopilot.ps1" -outputFile "C:\..\RegisterAutopilot.exe"
    
    .NOTES
    Written by: Jan aps

    .CHANGELOG
    V1.00, 2/12/2024 - Initial version
    v1.01, 14/01/2024 - Added other schools
#>
param(
    [Parameter(
        Mandatory = $true,
        HelpMessage = "Enter the GUID of the tenant")]
    [string]$tenantid = "changme",
    [Parameter(
        Mandatory = $true, HelpMessage = "Enter the app id found in your app registration")]
    [string]$AppId = "changeme",    
    [Parameter(
        Mandatory = $true
        HelpMessage = "Enter the app secret ")]
    [string]$AppSecret = "changeme"

)


# find execution folder
$mypath = $MyInvocation.MyCommand.Path
$executionFolder = Split-Path $mypath -Parent

# Path to the script Get-WindowsAutopilotInfo.ps1
$scriptPath = $executionFolder + "\Get-WindowsAutopilotInfo.ps1"

# variable to store choice 
$abbreviation = ""

# Define the schools and their abbreviation 
$schools = @{
    1  = @{ Name = "KNMC"; abb = "KNMC" }
    2  = @{ Name = "Lagere School Groenendaal"; abb = "LSG" }
    3  = @{ Name = "Moretus"; abb = "mrts" }
    4  = @{ Name = "Virgo Maria"; abb = "vgm" }
    5  = @{ Name = "JOMA basis"; abb = "jbm" }
    6  = @{ Name = "Kleuterschool Groenendaal"; abb = "kgr" }
    7  = @{ Name = "Sint-Jozef"; abb = "sjf" }
    8  = @{ Name = "OLV Lourdes"; abb = "olvl" }
    9  = @{ Name = "Sint-Mariaburg"; abb = "vbsm" }
    10 = @{ Name = "Sint-Lambertus"; abb = "slmb" }
    11 = @{ Name = "Sint-Vincent"; abb = "svc" }
    12 = @{ Name = "De Bunt"; abb = "dbnt" }
    13 = @{ Name = "Sint-Catharina"; abb = "sct" }
    14 = @{ Name = "Technicum"; abb = "tnc" }
    15 = @{ Name = "CLWA"; abb = "clwa" }
}

# Show the menu
Write-Host "Kies een school door het nummer in te voeren:"
foreach ($key in $schools.Keys) {
    Write-Host "$key. $($schools[$key].Name)"
}

# Read the users choice
$choice = Read-Host "Voer uw keuze in (1-$($schools.Count))"

# Check if choice is valid
if ($schools.ContainsKey([int]$choice)) {
    $chosenSchool = $schools[[int]$choice]
    $abbreviation = $chosenSchool.abb
    Write-Host "U heeft gekozen voor: $($chosenSchool.Name) ($abbreviation)"
}
else {
    Write-Host "Ongeldige keuze. Probeer het opnieuw."
}

# parameters to pass to the script
$AutopilotParams = @{
    Online    = $true
    TenantId  = $tenantid
    AppId     = $AppId
    AppSecret = $AppSecret
    GroupTag  = $abbreviation
}

# Call the script
& $scriptPath @AutopilotParams