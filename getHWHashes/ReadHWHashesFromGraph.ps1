
<#
    .SYNOPSIS
        Read collected hardware hashes

    .DESCRIPTION
    
        
    .LINK
        https://intunestuff.com/2023/12/14/how-to-harvest-the-autopilot-hardware-hash-file-from-existing-intune-non-autopilot-devices/
        https://techcommunity.microsoft.com/t5/device-management-in-microsoft/how-to-collect-custom-inventory-from-azure-ad-joined-devices/ba-p/2280850
        https://www.powershellgallery.com/packages/Get-WindowsAutoPilotInfo/3.5/Content/Get-WindowsAutoPilotInfo.ps1
    .NOTES
        
    Created: 16/05/2024
    Author: Jan Aps (jan.aps@noordkant.be)
#>


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

$graphUri = "https://graph.microsoft.com/beta/deviceManagement/deviceManagementScripts/" + $graphScriptID + "/deviceRunStates?`$expand=managedDevice"
$result = Invoke-MgGraphRequest -Uri $graphUri -Method GET 

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
# $objResultMessage | Out-GridView 
$objResultMessage | Export-Csv "c:\temp\hwid16-12-2024.csv"