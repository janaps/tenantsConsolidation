# load module
import-module "SharepointMigration.psm1"

#Read more: https://www.sharepointdiary.com/2021/03/copy-document-library-between-tenants-in-sharepoint-online-using-powershell.html#ixzz8wXUlgdBN
#region parameters
#Parameters
$SourceSiteURL = "https://XYZ.sharepoint.com/sites/XYZSITE"
$DestinationSiteURL = "https://XYZ.sharepoint.com/sites/XYZSite"


#parameters for connect-pnponline to the target tenant
#more info: https://github.com/pnp/PnP-PowerShell/tree/master/Samples/SharePoint.ConnectUsingAppPermissions
$targetSiteClientId = "changme"
$targetTenantDomain = "changme"
$targetCertPath = "changme" #absolute path to pfx-file of the

#parameters for connect-pnponline to the source tenant
#more info: https://github.com/pnp/PnP-PowerShell/tree/master/Samples/SharePoint.ConnectUsingAppPermissions
$sourceSiteClientId = "changme"
$sourceTenantDomain = "changme"
$sourceCertPath = "changme" #absolute path to pfx-file of the

$DownloadPath = "C:\Temp\MigrationDocs"

#endregion



##############################################################
# Step1: download all documents to local computer
# connect to source tenant; more info: https://www.sharepointdiary.com/2020/11/sharepoint-online-get-all-pages-using-powershell.html
Write-Host "Connecting to source sharepoint"
$sourceConnection = connect-pnponline -url $sourcesiteurl -ClientId $sourceSiteClientId -Tenant $sourceTenantDomain -CertificatePath $sourceCertPath -ReturnConnection

$sourceWeb = Get-PnPWeb -Connection $sourceConnection
$MetadataFile = "$DownloadPath\Metadata.csv"

#Delete any existing files and folders in the download location
If (Test-Path $DownloadPath) { Get-ChildItem -Path $DownloadPath -Recurse | ForEach-object { Remove-item -Recurse -path $_.FullName } }
 
Export-PnPLibraries -connection $sourceConnection -sourceWeb $sourceweb -SourcePath $DownloadPath
Disconnect-PnPonline

################################################################
# Step 2: import documents to target tenant

Write-Host "connecting to destination sharepoint"
$targetConnection = connect-pnponline -url $DestinationSiteURL -ClientId $targetSiteClientId -Tenant $targetTenantDomain -CertificatePath $targetCertPath -ReturnConnection
$TargetWeb = Get-PnPWeb -Connection $targetConnection

Import-PnPLibraries -connection $targetConnection -SetDocumentMetadata $false -SourcePath $DownloadPath


################################################################
# Step 3: Migrate Lists
Migrate-PnPLists -sourceConnection $sourceConnection -targetConnection $targetconnection

################################################################
# Step 3: Migrate site template
Migrate-SiteTemplate -sourceConnection $sourceConnection -targetConnection $targetConnection


################################################################
# Step 5: Migrate Site Pages
Migrate-SitePages -sourceConnection $sourceConnection -targetConnection $targetconnection -List "SitePagina's"



