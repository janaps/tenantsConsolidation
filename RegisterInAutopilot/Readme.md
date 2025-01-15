## RegisterInAutopilot

You can use these files to quickly register a device in Autopilot.

How to get things working quickly:

1.  Register an App in entra ID
    1.  go to [https://portal.azure.com/#view/Microsoft_AAD_IAM/ActiveDirectoryMenuBlade/~/RegisteredApps](https://portal.azure.com/#view/Microsoft_AAD_IAM/ActiveDirectoryMenuBlade/~/RegisteredApps)
    2.  Click on "New Registration", and give the app registration a name. Use the defaults
    3.  Once the app is created, head over to API permissions and hit “Add a permission”→ Microsoft Graph → Application permissions
    4.  Choose DeviceManagementServiceConfig → DeviceManagementServiceConfig.ReadWrite.All → Add permissions
    5.  In the next screen, click on Grant admin consent
2.  Add a secret
    1.  Go to Certificates & secrets and add a client secret
    2.  fill in the secret in the file RegisterInAutopilot.ps1

A workflow that I use to onboard various devices is the following:

1.  Create a bootable USB
    1.  download the latest Windows 11 ISO (https://www.microsoft.com/nl-nl/software-download/windows11)
    2.  download Rufus (https://rufus.ie/nl/)
    3.  use rufus to create the bootable usb
2.  Copy the three file in this folder to the root of the new usb
3.  Boot the device from the USB
4.  Once you are in OOBE, hit SHIFT+F10 to open a command prompt
5.  type run.cmd
