#Requires -Modules @{ ModuleName="PnP.PowerShell"; ModuleVersion="2.12.0" }
<#
    .SYNOPSIS
    MigrateSharePointSite

    .DESCRIPTION
    Copies document library and site pages with site assets

    .NOTES
    Written by: Jan Aps
    based on #Read more: https://www.sharepointdiary.com/2021/03/copy-document-library-between-tenants-in-sharepoint-online-using-powershell.html#ixzz8wXWAUCRt, but I added support 
    for multiple connections

    TODO: move system lists

    .CHANGELOG

#>

#region ExportFunctions

<#
.SYNOPSIS
Function to Extract Metadata of a File to CSV File

.PARAMETER SPFile
Parameter description

.PARAMETER connection
connection to sharepoint envirnonment
$sourceConnection = connect-pnponline -url $sourcesiteurl -ClientId $sourceSiteClientId -Tenant $sourceTenantDomain -CertificatePath $sourceCertPath -ReturnConnection

.PARAMETER SourceWeb
Web object
$sourceWeb = Get-PnPWeb -Connection $sourceConnection

.PARAMETER MetadataFile
The file to store the metadata in 

#>
Function Extract-PnPFileMetadata() {
    param (
        [Parameter(Mandatory = $true)] [Microsoft.SharePoint.Client.File]$SPFile,
        [Parameter(Mandatory = $true)] $connection,
        [Parameter(Mandatory = $true)] [Microsoft.SharePoint.Client.SecurableObject] $SourceWeb,
        [Parameter(Mandatory = $true)] [string]$MetadataFile
    )
    Try {
        #Calculate URLs
        $FileLibraryRelativeURL = $SPFile.ServerRelativeURL.Replace($global:Library.RootFolder.ServerRelativeURL, [string]::Empty)
        #Calculate Absolute URL
        If ($SourceWeb.ServerRelativeUrl -eq "/") {
            $FileAbsoluteURL = $("{0}{1}" -f $SourceWeb.Url, $SPFile.ServerRelativeUrl)
        }
        Else {
            $FileAbsoluteURL = $("{0}{1}" -f $SourceWeb.Url.Replace($SourceWeb.ServerRelativeUrl, [string]::Empty), $SPFile.ServerRelativeUrl)
        }
        #Get Autor, Editor of the file
        Get-PnPProperty -connection $connection -ClientObject $SPFile -Property Author, ModifiedBy
 
        #Extract the Metadata of the file
        $Metadata = New-Object PSObject
        $Metadata | Add-Member -MemberType NoteProperty -name "FileName" -value $SPFile.Name
        $Metadata | Add-Member -MemberType NoteProperty -name "ParentLibrary" -value $global:Library.Title
        $Metadata | Add-Member -MemberType NoteProperty -name "FileAbsoluteURL" -value $FileAbsoluteURL
        $Metadata | Add-Member -MemberType NoteProperty -name "FileLibraryRelativeURL" -value $FileLibraryRelativeURL
        $Metadata | Add-Member -MemberType NoteProperty -Name "CreatedBy" -value $SPFile.Author.LoginName
        $Metadata | Add-Member -MemberType NoteProperty -name "ModifiedBy" -value $SPFile.ModifiedBy.LoginName
        $Metadata | Add-Member -MemberType NoteProperty -name "CreatedOn" -value $SPFile.TimeCreated
        $Metadata | Add-Member -MemberType NoteProperty -name "ModifiedOn" -value $SPFile.TimeLastModified
  
        #Send the Metadata to CSV File
        $Metadata | Export-Csv $MetadataFile -NoTypeInformation -Append
        Write-host -f Green "`t`tMetadata Extracted from the File:"$SPFile.ServerRelativeURL
    }
    Catch {
        write-host -f Red "Error Getting Metadata:" $_.Exception.Message
    }
}
 
<#
.SYNOPSIS

#Function to Download a Document Library from SharePoint Online site

.DESCRIPTION
Long description

.PARAMETER LibraryName
the library to download

.PARAMETER connection
connection to sharepoint envirnonment
$sourceConnection = connect-pnponline -url $sourcesiteurl -ClientId $sourceSiteClientId -Tenant $sourceTenantDomain -CertificatePath $sourceCertPath -ReturnConnection


.PARAMETER SourcePath
the path on the local computer to store the library on
.PARAMETER SourceWeb
Web object
$sourceWeb = Get-PnPWeb -Connection $sourceConnection

.PARAMETER ExtractMetaData
extract the metadata yes or no: speeds up the process if you are not going to use it

.PARAMETER MetadataFile
full path to the .csv-file

#>
Function Export-PnPLibrary() {
    param
    (
        [Parameter(Mandatory = $true)] [string]$LibraryName,
        [Parameter(Mandatory = $true)] $connection,
        [Parameter(Mandatory = $true)] [string] $SourcePath,
        [Parameter(Mandatory = $true)] [Microsoft.SharePoint.Client.SecurableObject] $SourceWeb,
        [Parameter(Mandatory = $false)][bool] $ExtractMetaData = $false,
        [Parameter(Mandatory = $false)] [string]$MetadataFile
    )
    
 
    Try {
        Write-host "Exporting Library:"$LibraryName -f Yellow
 
        #Get the Library
        $global:Library = Get-PnPList -Connection $connection -Identity $LibraryName -Includes RootFolder
 
        #Create a Local Folder for Document Library, if it doesn't exist
        $LocalFolder = $SourcePath + "\" + $global:Library.RootFolder.Name
        If (!(Test-Path -Path $LocalFolder)) {
            New-Item -ItemType Directory -Path $LocalFolder | Out-Null
        }
        Write-host -f Yellow "`tEnsured Folder for Document Library '$LocalFolder'"
 
        #Get all Items from the Library - with progress bar
        $global:counter = 0
        $LibraryItems = Get-PnPListItem -Connection $connection -List $LibraryName -PageSize 500 -Fields ID, FieldValues -ScriptBlock { Param($items) $global:counter += $items.Count; Write-Progress -PercentComplete `
            ($global:Counter / ($global:Library.ItemCount) * 100) -Activity "Getting Items from Library:" -Status "Processing Items $global:Counter to $($global:Library.ItemCount)"; }
        Write-Progress -Activity "Completed Retrieving Folders from Library $LibraryName" -Completed
 
        #Get all Subfolders of the library
        $SubFolders = $LibraryItems | Where-Object { $_.FileSystemObjectType -eq "Folder" -and $_.FieldValues.FileLeafRef -ne "Forms" }
        $SubFolders | ForEach-Object {
            #Ensure All Folders in the Local Path
            $LocalFolder = $SourcePath + ($_.FieldValues.FileRef.Substring($SourceWeb.ServerRelativeUrl.Length)) -replace "/", "\"
            #Create Local Folder, if it doesn't exist
            If (!(Test-Path -Path $LocalFolder)) {
                New-Item -ItemType Directory -Path $LocalFolder | Out-Null
            }
            Write-host -f Yellow "`tEnsured Folder '$LocalFolder'"
        }
 
        #Get all Files from the folder
        $FilesColl = $LibraryItems | Where-Object { $_.FileSystemObjectType -eq "File" }
 
        $global:Filess = $FilesColl
        #Iterate through each file and download
        $FilesColl | ForEach-Object {
            Try {
                $FileDownloadPath = ($SourcePath + ($_.FieldValues.FileRef.Substring($sourceWeb.ServerRelativeUrl.Length)) -replace "/", "\").Replace($_.FieldValues.FileLeafRef, [string]::Empty)
                Get-PnPFile -Connection $connection -Url $_.FieldValues.FileRef -Path $FileDownloadPath -FileName $_.FieldValues.FileLeafRef -AsFile -Force -ErrorAction Stop
                Write-host -f Green "`tDownloaded File from '$($_.FieldValues.FileRef)'"
                 
                #Get the Metadata of the File
                $File = Get-PnPProperty -connection $connection -ClientObject $_ -Property File
                if ($ExtractMetaData) {
                    Extract-PnPFileMetadata -connection $connection -SPFile $File -SourceWeb $SourceWeb -MetadataFile $MetadataFile
                }
            }
            Catch {
                write-host -f Red "`tError Downloading File from '$($_.FieldValues.FileRef)' : "$_.Exception.Message
            }
        }
    }
    Catch {
        write-host -f Red "`tError:" $_.Exception.Message
    }
}

<#
.SYNOPSIS
Function to export all libraries in a SharePoint Site


.PARAMETER connection
connection to sharepoint envirnonment
$sourceConnection = connect-pnponline -url $sourcesiteurl -ClientId $sourceSiteClientId -Tenant $sourceTenantDomain -CertificatePath $sourceCertPath -ReturnConnection


.PARAMETER SourceWeb
Web object
$sourceWeb = Get-PnPWeb -Connection $sourceConnection

.PARAMETER SourcePath
the path on the local computer to store the library onn

#>
Function Export-PnPLibraries() {
    param(
        [Parameter(Mandatory = $true)] $connection,
        [Parameter(Mandatory = $true)] [Microsoft.SharePoint.Client.SecurableObject] $SourceWeb,
        [Parameter(Mandatory = $true)] [string] $SourcePath
    )
    Try {
        #Arry to Skip System Lists and Libraries
        $SystemLists = @("Converted Forms", "Master Page Gallery", "Customized Reports", "Form Templates", "List Template Gallery", "Theme Gallery",
            "Reporting Templates", "Solution Gallery", "Style Library", "Web Part Gallery", "Site Assets", "wfpub", "Site Pages", "Images", "Sitepagina's", 
            "Siteactiva", "SiteAssets", "SitePages", "Formuliersjablonen", "Stijlbibliotheek")
      
        #Filter Document Libraries to Scan
        $LibraryCollection = Get-PnPList -Connection $connection | Where-Object { $_.BaseType -eq "DocumentLibrary" -and $_.Hidden -eq $false -and $SystemLists -notcontains $_.Title -and $_.ItemCount -gt 0 }
         
        #Loop through each document library
        ForEach ($Library in $LibraryCollection) {
            #Call the function to download the document library
            Export-PnPLibrary -LibraryName $Library.Title -connection $connection -SourceWeb $SourceWeb -SourcePath $SourcePath
        }
    }
    Catch {
        Write-host -f Red "Error Downloading Libraries:" $_.Exception.Message
    }
}

#endregion ExportFunctions

#region ImportFunctions

<#
.SYNOPSIS
Function to Ensure SharePoint Online User

.PARAMETER UserID
user id

.PARAMETER connection
the pnp connection
$targetConnection = connect-pnponline -url $DestinationSiteURL -ClientId $targetSiteClientId -Tenant $targetTenantDomain -CertificatePath $targetCertPath -ReturnConnection

#>
Function Ensure-PnPUser() {
    param(
        [Paramater(Mandatory = $true)][string]$UserID,
        [Parameter(Mandatory = $true)]$connection
    )
    Try {
        #Try to Get the User
        $User = Get-PnPUser -connection $connection -Identity $UserID
 
        If ($null -eq $User) {
            $User = New-PnPUser -connection $connection -LoginName $UserID
        }
        #Return the User Object
        $User
    }
    Catch {
        write-host -f Red "`t`t`tError Resolving User $UserID :" $_.Exception.Message
        Return $Null
    }
}
 
#
<#
.SYNOPSIS
Function to Set the Metadata of a Document

.PARAMETER File
the file

.PARAMETER TargetLibrary
the target library

.PARAMETER connection
the pnp-connection
$targetConnection = connect-pnponline -url $DestinationSiteURL -ClientId $targetSiteClientId -Tenant $targetTenantDomain -CertificatePath $targetCertPath -ReturnConnection

.PARAMETER MetadataFile
the file with the metadata in

#>
Function SetPnP-DocumentMetadata() {
    param
    (
        [Parameter(Mandatory = $true)] [Microsoft.SharePoint.Client.File] $File,
        [Parameter(Mandatory = $true)] [Microsoft.SharePoint.Client.List] $TargetLibrary,
        [Parameter(Mandatory = $true)]$connection,
        [Parameter(Mandatory = $true)][string]$MetadataFile   
    )
    Try {
        #Calculate the Library Relative URL of the File
        $TargetFolder = Get-PnPProperty -connection $connection -ClientObject $TargetLibrary -Property RootFolder
        $FileLibraryRelativeURL = $File.ServerRelativeUrl.Replace($TargetLibrary.RootFolder.ServerRelativeUrl, [string]::Empty)       
        $FileItem = Get-PnPProperty -connection $connection -ClientObject $File -Property ListItemAllFields
 
        #Import Metadata CSV File
        $MetadataFile = Import-Csv -LiteralPath $MetadataFile
        #Get the Metadata of the File
        $Metadata = $MetadataFile | Where-Object { ($_.ParentLibrary -eq ($TargetLibrary.Title)) -and $_.FileLibraryRelativeURL -eq $FileLibraryRelativeURL }
        If ($Metadata) {
            Write-host -f Yellow "`t`tUpdating Metadata for File '$($File.ServerRelativeURL)'"
 
            #Get 'Created By' and 'Modified By' Users
            $FileMetadata = @{}
            $Author = Ensure-PnPUser -UserID $Metadata.CreatedBy
            $Editor = Ensure-PnPUser -UserID $Metadata.ModifiedBy
            $FileMetadata.add("Created", [DateTime]$Metadata.CreatedOn)
            $FileMetadata.add("Modified", [DateTime]$Metadata.ModifiedOn)
 
            If ($Null -ne $Author) {
                $FileMetadata.add("Author", $Author.LoginName)
            }
            If ($Null -ne $Editor) {
                $FileMetadata.add("Editor", $Editor.LoginName)
            }
            #Update document properties
            Set-PnPListItem -connection $connection -List $TargetLibrary -Identity $FileItem.Id -Values $FileMetadata | Out-Null
            Write-host -f Green "`t`t`tMetadata has been Updated Successfully!"
        }
    }
    Catch {
        write-host -f Red "`t`t`tError updating Metadata of the Document:"$_.Exception.Message
    }
}
  

<#
.SYNOPSIS
Function to Import all Files and Folders from Local Folder to SharePoint Online

.PARAMETER SourceLibraryPath
the library stored on local computer

.PARAMETER TargetLibrary
the library to wich to import the documents to

.PARAMETER connection
the pnp connection
$targetConnection = connect-pnponline -url $DestinationSiteURL -ClientId $targetSiteClientId -Tenant $targetTenantDomain -CertificatePath $targetCertPath -ReturnConnection


.PARAMETER SetDocumentMetadata
wether or not to set the document metadata, speeds up the process 

.PARAMETER MetadataFile
the metadata file

#>
Function ImportPnP-Library() {
    param
    (
        [Parameter(Mandatory = $true)] [string] $SourceLibraryPath,
        [Parameter(Mandatory = $true)] [Microsoft.SharePoint.Client.List] $TargetLibrary,
        [Parameter(Mandatory = $true)]$connection,
        [Parameter(Mandatory = $false)][bool] $SetDocumentMetadata = $false,
        [Parameter(Mandatory = $false)][string]$MetadataFile
    )
    Try {
        #Get the Target Folder to Upload
        $TargetFolder = Get-PnPProperty -connection $connection -ClientObject $TargetLibrary -Property RootFolder
        $targetfolder
        $TargetFolderSiteRelativeURL = $TargetFolder.ServerRelativeURL.Replace($targetWeb.ServerRelativeUrl + "/", [string]::Empty)
        write-host "targetfoldrelurl $TargetFolderSiteRelativeURL"
        Get-ChildItem $SourceLibraryPath -Recurse | ForEach-Object {
            $TargetFolderRelativeURL = $TargetFolderSiteRelativeURL + $_.FullName.Replace($SourceLibraryPath, [string]::Empty).Replace("\", "/")
            #write-host $TargetFolderRelativeURL
            If ($_.PSIsContainer -eq $True) {
                #If its a Folder, ensure it!
                Write-host -f Yellow "`t`tEnsuring Folder '$TargetFolderRelativeURL'"
                #Ensure Folder
                Resolve-PnPFolder -connection $connection -SiteRelativePath $TargetFolderRelativeURL #| Out-Null
            }
            Else {
                #Its a File, Upload it!
                #Calculate the Parent Folder for File
                $TargetFolderURL = (Split-Path $TargetFolderRelativeURL -Parent).Replace("\", "/")               
                $SourceFilePath = $_.FullName
   
                Write-host -f Yellow "`t`tUploading File '$_' to Folder:"$TargetFolderURL
                $File = Add-PnPFile -connection $connection -Path $SourceFilePath -Folder $TargetFolderURL
                Write-host "`t`t`tFile Uploaded Successfully!" -ForegroundColor Green
                  
                #Update Metadata of the File
                if ($SetDocumentMetadata) {
                    SetPnP-DocumentMetadata -connection $connection  -File $File -TargetLibrary $TargetLibrary -MetadataFile $MetadataFile
                }
            }
        }
    }
    Catch {
        write-host -f Red "`t`t`tError Importing Library:" $_.Exception.Message
    }
}
  

<#
.SYNOPSIS
Function to Ensure a SharePoint Online document library

.PARAMETER LibraryName
the name of the library

.PARAMETER Connection
the pnp-connection

#>
Function EnsurePnP-DocumentLibrary() {
    param
    (
        [Parameter(Mandatory = $true)] [string] $LibraryName,
        [Parameter(Mandatory = $true)] $Connection
    )   
    Try {
        Write-host -f Yellow "`nEnsuring Library '$LibraryName'"
          
        #Check if the Library exist already
        $List = Get-PnPList -connection $connection | Where-Object { $_.Title -eq $LibraryName }
 
        If ($Null -eq $List) {
            #Create Document Library
            $List = New-PnPList -connection $connection -Title $LibraryName -Template DocumentLibrary -OnQuickLaunch 
            write-host  -f Green "`tNew Document Library '$LibraryName' has been created!"
        }
        Else {
            #Get the Library
            $List = Get-PnPList -connection $connection -Identity $LibraryName
            Write-Host -f Magenta "`tA Document Library '$LibraryName' Already exist!"
        }
        Return $List
    }
    Catch {
        write-host -f Red "`tError Creating Document Library!" $_.Exception.Message
    }
}
  
#Main Function
<#
.SYNOPSIS
Import all given document libraries


.PARAMETER connection
the pnp connection
$targetConnection = connect-pnponline -url $DestinationSiteURL -ClientId $targetSiteClientId -Tenant $targetTenantDomain -CertificatePath $targetCertPath -ReturnConnection

.PARAMETER SetDocumentMetadata
Parameter description

.PARAMETER SourcePath
Parameter description

.PARAMETER MetadataFile
wether or not to set the document metadata, speeds up the process 


#>
Function Import-PnPLibraries() {
    param(
        [Parameter(Mandatory = $true)] [System.Object]$connection,
        [Parameter(Mandatory = $false)][bool] $SetDocumentMetadata = $false,
        [Parameter(Mandatory = $true)][string] $SourcePath,
        [Parameter(Mandatory = $false)][string]$MetadataFile

    )
    Try {
        #Get Top Level Folders from the Source as "Document Libraries"
        $SourceLibraries = Get-ChildItem -Directory -Path $SourcePath
  
        #Create Document Libraries
        ForEach ($SourceLibrary in $SourceLibraries) {
            #call the function to Ensure document library
            $TargetLibrary = EnsurePnP-DocumentLibrary -connection $connection -LibraryName $SourceLibrary.Name
  
            #Import Files and Folders from the Source to the Destination
            ImportPnP-Library -connection $connection -SourceLibraryPath $SourceLibrary.FullName -TargetLibrary $TargetLibrary -MetadataFile $MetadataFile -SetDocumentMetadata $SetDocumentMetadata
        }
    }
    Catch {
        write-host -f Red "Error:" $_.Exception.Message
    }
}


#Read more: https://www.sharepointdiary.com/2021/03/copy-document-library-between-tenants-in-sharepoint-online-using-powershell.html#ixzz8wXatB6JS
#endregion

#region sitepages
function Migrate-SitePages() {
    param(
        [Parameter(Mandatory = $true)] [System.Object]$sourceConnection,
        [Parameter(Mandatory = $true)] [System.Object]$targetConnection,
        [Parameter(Mandatory = $false)][string] $List = "SitePagina's",
        [Parameter(Mandatory = $false)][string] $exportDirectory = $env:temp
    )
    $SitePages = Get-PnPListItem -List $List -Connection $sourceConnection
    $PagesDataColl = @()
    #Collect Site Pages data - Title, URL and other properties
    ForEach ($Page in $SitePages) {
    
        $Data = New-Object PSObject -Property ([Ordered] @{
                PageName      = $Page.FieldValues.Title
                RelativeURL   = $Page.FieldValues.FileRef
                PageNameFull  = $Page.FieldValues.FileLeafRef     
                CreatedBy     = $Page.FieldValues.Created_x0020_By
                CreatedOn     = $Page.FieldValues.Created
                ModifiedOn    = $Page.FieldValues.Modified
                ModifiedBy    = $Page.FieldValues.Editor.Email
                ID            = $Page.ID
                PromotedState = $Page.FieldValues.PromotedState
                Title         = $Page.FieldValues.Title
                PageLayout    = $Page.FieldValues.PageLayoutType
            })
        $PagesDataColl += $Data
    }
    foreach ($page in $PagesDataColl) {
        Write-host "Importing page $page"
        # export from source tenant
        Export-PnPPage -Force -Identity $page.PageNameFull -Out "$exportDirectory\$($page.PageNameFull)" -Connection $sourceConnection -PersistBrandingFiles
        write-host "path  = $exportDirectory\$($page.PageNameFull)"

        # applying to destination
        Invoke-PnPSiteTemplate -Path "$exportDirectory\$($page.PageNameFull)" -Connection $targetConnection -ResourceFolder $exportDirectory
    

    }

}
#Read more: https://www.sharepointdiary.com/2020/11/sharepoint-online-get-all-pages-using-powershell.html#ixzz8f6hzLAQF
#endregion

#region migrate functions
<#
.SYNOPSIS
Function to migrate a named list from one sharepoint site to another sharepoint site

.PARAMETER ListName
the name of the list

.PARAMETER sourceConnection
connection to the source site

.PARAMETER targetConnection
connection to the target site

#>
Function Migrate-PnPList() {
    param
    (
        [Parameter(Mandatory = $true)] [string]$ListName,
        [Parameter(Mandatory = $true)] $sourceConnection,
        [Parameter(Mandatory = $true)] $targetConnection
    )

    $tempfile = [System.IO.Path]::GetTempFileName()

    # export the definition of the list
    Get-PnPSiteTemplate -Connection $sourceConnection -IncludeAllPages -Handlers Lists -ListsToExtract $ListName -out ("{0}{1}.xml" -f $tempfile, $ListName)
    
    # export the data of the list
    Add-PnPDataRowsToSiteTemplate -path "$tempfile" -List "$ListName" -Connection $sourceConnection

    # import everything to the destionation sharepoint
    invoke-PnPSiteTemplate -Path  $tempfile -Connection $targetConnection

    # remove the tempfile
    Remove-Item -Path $tempfile -Force:$true -Confirm:$false
}

<#
.SYNOPSIS
Migrate all lists in a sharepoint site

.PARAMETER sourceConnection
connection to the source site

.PARAMETER targetConnection
connection to the target site


.NOTES
General notes
#>
Function Migrate-PnPLists() {
    param(
        [Parameter(Mandatory = $true)] $sourceConnection,
        [Parameter(Mandatory = $true)] $targetConnection
    )

    # get the lists in the site
    $lists = Get-PnPList -connection $sourceconnection | Where-Object { $_.RootFolder.ServerRelativeUrl -like "*/Lists/*" -and $_.Hidden -eq $false }
    $lists | ForEach-Object {
        Migrate-PnPList -sourceConnection $sourceConnection -targetConnection $targetConnection -ListName $_.Title
    }

}
<#
.SYNOPSIS
migrate the site template

.PARAMETER sourceConnection
connection to the source site

.PARAMETER targetConnection
connection to the target site

.NOTES
General notes
#>
function Migrate-SiteTemplate {
    param(
        [Parameter(Mandatory = $true)] [System.Object]$sourceConnection,
        [Parameter(Mandatory = $true)] [System.Object]$targetConnection
    )
    

    # get the site template
    $template = Get-PnPSiteTemplate  -PersistBrandingFiles -PersistPublishingFiles -Connection $sourceConnection -OutputInstance

    # apply the template
    Invoke-PnPSiteTemplate -Path .\ -ClearNavigation -Connection $targetConnection -InputInstance $template

}

#endregion



