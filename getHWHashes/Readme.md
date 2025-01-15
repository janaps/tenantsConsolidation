## **getHWHashes**

If you want to migrate your devices from one tenant to another, you have to delete all Autopilot hashes from the source tenant and import them into the target tenant.  
Microsoft doesn't provide a way to export those hashes from you source tenant. Luckally, there is a workaround. Every script you deploy through intune can have an output, errorcode etc. This info is stored in Intune and can be queried through Graph

The worklow is as follows

### 1\. Collect all hardware hashes in the source tenant

1.  Head over to intune.microsoft.com → Devices → Scripts and remediations → Tab Platform scripts
2.  Add Windows 10 and later
3.  Give your script a name
4.  Script settings:
    1.  upload the script [CollectHWhash.ps1](https://github.com/janaps/tenantsConsolidation/blob/main/getHWHashes/CollectHWhash.ps1)
    2.  Run this script using the logged on credentials: no
    3.  Enfor script signature check: no
    4.  Run script in 64 bit Powershell Host: no
5.  Under assignments: target all the devices you want, normally you would target all devices in the tenant
6.  Wait until all devices have executed the script

### 2\. Delete all autopilot hashes in the source tenant

1.  Go to [https://intune.microsoft.com/#view/Microsoft_Intune_Enrollment/AutopilotDevices.ReactView](https://intune.microsoft.com/#view/Microsoft_Intune_Enrollment/AutopilotDevices.ReactView)
2.  Select all devices
3.  _**Take a deep breath, because this cannot be undone!!!**_
4.  Delete

### 3\. Import hardware hashes in the target tenant

I have provide two ways to import the hashes into your tenant: through a csv you import or through powershell. Either way, you have to find the guid of the script you uploaded before:

1.  Go to https://endpoint.microsoft.>com->Devices->Widows->Scripts and remediation. Click on tab Platform scripts
2.  Now click on the script you deployed previously and find the guid of the script in the url. It is the portion after policyID and before the policyType portion(without the slashes)

#### A. CSV-import

Use the script
