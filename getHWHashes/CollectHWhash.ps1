
<#
    .SYNOPSIS
        Collect hardwarehashes in an existing entra tenant

    .DESCRIPTION
    You have to deploy this script through intune in order to collect the hardware hashes thru ReadHWHash.ps1
        
    .LINK
        https://intunestuff.com/2023/12/14/how-to-harvest-the-autopilot-hardware-hash-file-from-existing-intune-non-autopilot-devices/
        https://techcommunity.microsoft.com/t5/device-management-in-microsoft/how-to-collect-custom-inventory-from-azure-ad-joined-devices/ba-p/2280850
        https://www.powershellgallery.com/packages/Get-WindowsAutoPilotInfo/3.5/Content/Get-WindowsAutoPilotInfo.ps1
    .NOTES
        Created: 16/05/2024
        Author: Jan Aps (jan.aps@noordkant.be)
#>



#from https://www.powershellgallery.com/packages/Get-WindowsAutoPilotInfo/3.5/Content/Get-WindowsAutoPilotInfo.ps1
# Get the common properties.
$session = New-CimSession
$serial = (Get-CimInstance -CimSession $session -Class Win32_BIOS).SerialNumber

$bad = $false
# Get the hash (if available)
$devDetail = (Get-CimInstance -CimSession $session -Namespace root/cimv2/mdm/dmmap -Class MDM_DevDetail_Ext01 -Filter "InstanceID='Ext' AND ParentID='./DevDetail'")
if ($devDetail -and (-not $Force)) {
    $hash = $devDetail.DeviceHardwareData
}
else {
    $bad = $true
    $hash = ""
}

# If the hash isn't available, get the make and model
if ($bad -or $Force) {
    $cs = Get-CimInstance -CimSession $session -Class Win32_ComputerSystem
    $make = $cs.Manufacturer.Trim()
    $model = $cs.Model.Trim()
    if ($Partner) {
        $bad = $false
    }
}
else {
    $make = ""
    $model = ""
}

# Getting the PKID is generally problematic for anyone other than OEMs, so let's skip it here
$product = ""


# Create a pipeline object
$c = New-Object psobject -Property @{
    "Device Serial Number" = $serial
    "Windows Product ID"   = $product
    "Hardware Hash"        = $hash
}
            
if ($GroupTag -ne "") {
    Add-Member -InputObject $c -NotePropertyName "Group Tag" -NotePropertyValue $GroupTag
}
if ($AssignedUser -ne "") {
    Add-Member -InputObject $c -NotePropertyName "Assigned User" -NotePropertyValue $AssignedUser
}


# Write the object to the pipeline or array
if ($bad) {
    # Report an error when the hash isn't available
    Write-Error -Message "Unable to retrieve device hardware data (hash) from computer $comp" -Category DeviceError
}
$c | ConvertTo-Json -Compress


Remove-CimSession $session
