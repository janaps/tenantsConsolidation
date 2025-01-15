
<#
    .SYNOPSIS
    Add hashes to Intune autopilot

    .DESCRIPTION

    This script allows you to read the output from a script that reads the hardware hashes from devices. You should first deploy 
    the script AddHashesToIntune.ps1 on all devices you want the hardware hash from.
    The script allso adds the hardware hashes to autopilot 

        https://intunestuff.com/2023/12/14/how-to-harvest-the-autopilot-hardware-hash-file-from-existing-intune-non-autopilot-devices/
        https://techcommunity.microsoft.com/t5/device-management-in-microsoft/how-to-collect-custom-inventory-from-azure-ad-joined-devices/ba-p/2280850
        https://www.powershellgallery.com/packages/Get-WindowsAutoPilotInfo/3.5/Content/Get-WindowsAutoPilotInfo.ps1
    .LINK

        https://www.powershellgallery.com/packages/Get-WindowsAutoPilotInfo/3.5/Content/Get-WindowsAutoPilotInfo.ps1
    .NOTES
        Created: 16/12/2024
        Author: Jan Aps (jan.aps@noordkant.be)
#>



# required graph permissions, I am probably over reaching here
$mgraphPerm = "Directory.AccessAsUser.All,DeviceManagementServiceConfig.ReadWrite.All,DeviceManagementConfiguration.ReadWrite.All,DeviceManagementRBAC.ReadWrite.All,AdministrativeUnit.Read.All,AdministrativeUnit.ReadWrite.All,Directory.ReadWrite.All,Directory.Read.All,Group.ReadWrite.All,GroupMember.ReadWrite.All,RoleManagement.ReadWrite.Directory" #msgraph necessary scopes

# make connection
Write-Output "Connecting to MsGraph"
$sourcetenantid = Read-Host "Provide the source Tenant ID"

# Connect-MgGraph -Scopes $mgraphPerm -TenantId $TenantId -ContextScope Process
$sourceTenant = Connect-MgGraph -Scopes $mgraphPerm -TenantId $sourcetenantid -ContextScope Process

# ask about the script id
Write-Host "Go to https://endpoint.microsoft.>com->Devices->Widows->Scripts and remediation. Click on tab `"Platform scripts `""
Write-Host "Now click on the script you deployed previously and find the guid of the script in the url."
Write-Host "It is the portion after policyID and before the policyType portion(without the slashes)"
$graphScriptID = Read-Host "Provide the script id"
Write-host "Getting the hardwarehashes from intune"

$graphUri = "https://graph.microsoft.com/beta/deviceManagement/deviceManagementScripts/" + $graphScriptID + "/deviceRunStates?`$expand=managedDevice"
$result = Invoke-MgGraphRequest -Uri $graphUri -Method GET 

Write-Host "You have to provide a grouptag to the devices"
$groupTag = Read-Host "Provide the grouptag"

# pagination according to https://medium.com/@mozzeph/how-to-handle-microsoft-graph-paging-in-powershell-354663d4b32a
$allPages = @()
$allPages.Clear()
$allPages += $result.value
if ($result.'@odata.nextLink') {
    do {
        $result = Invoke-MgGraphRequest -Uri $result.'@odata.nextLink' -Method GET
        $allPages += $result.value
    }until(
        !$result.'@odata.nextLink'
    )
}


$success = $allPages | Where-Object -Property errorCode -EQ 0
$resultMessage = $success.resultMessage 
$objResultMessage = $resultMessage | ConvertFrom-Json

# uncomment these next 2 lines if you want to import your own csv
# $objResultMessage | Out-GridView 
#$objResultMessage
Disconnect-MgGraph 

# all the results are collected, now we need to connect to the target tenant
Write-Host "results collected, getting ready to connect to target tenant"
$targetTenantId = "Provide the tenant Id for the target tenant"
Connect-MgGraph -Scopes $mgraphPerm -TenantId $targetTenanttenantid -ContextScope Process

$lines = $objResultMessage
foreach ($line in $lines) {
    # test if the device is registered in autopilot
    $autopilotDevice = get-autopilotDevice -serial $line.'Device Serial Number'
    if ($null -eq $autopilotDevice) {
        # the device is not found in autopilot, try to register it
        Add-AutopilotImportedDevice -serialNumber $line.'Device Serial Number' -hardwareIdentifier $line.'Hardware Hash' -groupTag $groupTag
        Write-Host "$line.'Device Serial Number' added"

    }
    else {
        # the device is found, just be verbose in the output
        Write-Host "$($autopilotDevice.serialNumber) allready in autopilot"
    }
}

# Write-Information "Starting autopilot sync"
Invoke-AutopilotSync.git\

Disconnect-MgGraph 