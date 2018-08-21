##############################
# FSRM_NoCrypto_2016.ps1     #
# W2012, 2012R2 and 2016     #
# David ANDE - ALTAE         #
# WWW.ALTAE.NET              #
# GNU GENERAL PUBLIC LICENSE #
##############################


# First of all powershell 3 or higher is needed
# This scripts is not compatible with Powershell v2

$powershellVer = $PSVersionTable.PSVersion.Major

if ($powershellVer -le 2)
{
    Write-Host "`n####"
    Write-Host "ERROR: PowerShell v3 or higher required."
    exit
}

########## VARIABLE TO MODIFY #############
# $wkdir is where the scripts are
# better using this one
$wkdir = "C:\FSRMNOCRYPTO"

# $url is where to donwload extensionnlist from
# don't change if You don't know what You are doing
$url = "https://fsrm.experiant.ca/api/v1/get"

# Group Name in FSRM #
$fileGroupName = "ALTAE_CryptoBlocker_extensions"
$fileTemplateName = "ALTAE_TemplateBlocker_Crypto"
$fileScreenName = "ALTAE_FiltreBlocker_Crypto"
#############################################

# Drives to exclude for FSRM bloking
# If You want to exclude complete Path or special directory so write for exemple "C:\share" for  specific share 
# or "D:\shar*" for all shares in D starting by shar or "E:\*" for all shares in E
# or"D:\*shar*"for all shares in D containing shar.
# If nothing to exclude let the value to "0". only one value per line so only 2 exclusions for the moment :-)
# ex: $drive_exclu1= "C:\Windows*"
$drive_exclu1 = "0"
$drive_exclu2 = "0"
#############################################
Try
{
# Verifying if new crypto extensions available #
Invoke-WebRequest $url -OutFile $wkdir\extensions.txt

$dif = compare-object -referenceobject $(get-content "$wkdir\extensions.txt") -differenceobject $(get-content "$wkdir\extensions.old")

if (!$dif) { 
Write-Host "`n####"
Write-Host "No new extensions to apply - Quit"
rm $wkdir\extensions.txt
exit 
}
}
Catch
{
Write-Host "`n####"
Write-Host "Remote extension list Offline - Quit"
If (Test-Path "$wkdir\extensions.txt")
{rm $wkdir\extensions.txt}

else
{
exit 
}
}
Write-Host New Crypto extensions available will be added to FSRM

# Listing all shared drives#
$drivesContainingShares = Get-WmiObject Win32_Share | Select Name,Path,Type | Where-Object { $_.Type -match  '0|2147483648' } | Select -ExpandProperty Path | Select -Unique


$drivesContainingShares >> "$wkdir\drivesbase.txt"
if ($drive_exclu2 -ne '0' ) {
    $drives_filter = (Get-Content "$wkdir\drivesbase.txt" | where { $_ -notlike "$drive_exclu1"} | where { $_ -notlike "$drivee_xclu2"})
    $drivesContainingShares = $drivesfilter}
    Else {
    if ($drive_exclu1 -ne '0') {
    $drivesfilter = (Get-Content "$wkdir\drivesbase.txt" | where { $_ -notlike "$drive_exclu1"})
    $drivesContainingShares = $drivesfilter}
    Else {
    }
    }
Write-Host "Shared filtered"
Write-Host "Drives to be protected: $($drivesContainingShares -Join ",")"

# Command to be lunch in case of violation of Anticrypto FSRM rules #
# defdault rule is non but You can use this one by adding 
# $Command to the notification in the Template
# This command stop lanmaserver to stop all shares
# To restart the service use the comman "net start lanmanserver"
$Commande = New-FsrmAction -Type Command -Command "c:\Windows\System32\cmd.exe" -CommandParameters "/c net stop lanmanserver /y" -SecurityLevel LocalSystem -KillTimeOut 0

###################################################################################################
   
# Fonction to convert the extensions list #
# in a compatible FSRM format             #                       

function ConvertFrom-Json20([Object] $obj)
{
    Add-Type -AssemblyName System.Web.Extensions
    $serializer = New-Object System.Web.Script.Serialization.JavaScriptSerializer
    return ,$serializer.DeserializeObject($obj)
}

Try
{
$jsonStr = Invoke-WebRequest -Uri $url
$monitoredExtensions = @(ConvertFrom-Json20($jsonStr) | % { $_.filters })
$monitoredExtensions >> "$wkdir\extsbase.txt"
}
Catch
{
Write-Host Error parsing extension list - Quit
rm $wkdir\drivesbase.txt
rm $wkdir\extensions.txt
exit
}

$ext_filter = Compare-Object $(Get-content "$wkdir\extsbase.txt") $(Get-content "$wkdir\ext_to_accept.txt") -IncludeEqual | where-object {$_.SideIndicator -eq "<="} | select InputObject | select -ExpandProperty InputObject

# Destination mail adress Modify if You use mail notification
# in the case of Mail Notification check your SMTP setting in the FSRM Options
$maildestination = "XXXXXX@XXX.XX"

$MailNotification = New-FsrmAction -Type Email -MailTo "$maildestination" -Subject "Cryptolocker Alert" -Body "The user [Source Io Owner] try to save [Source File Path] in [File Screen Path] on [Server]. This extension is contained in [Violated File Group], and is not permit on this server." -RunLimitInterval 60 
###############################################

$EventNotification = New-FsrmAction -Type Event -EventType Warning -Body "The user [Source Io Owner] try to save [Source File Path] in [File Screen Path] on [Server]. This extension is contained in [Violated File Group], and is not permit on this server." -RunLimitInterval 60

# Removing FSRM File Screens if allready exist
$delFSRMShares= Get-FsrmFileScreen | Select Template, Path | Where-Object {$_.Template -like "$fileTemplateName"} | Select -ExpandProperty Path
foreach ($Path in $delFSRMShares) {
Remove-FsrmFileScreen $Path -Confirm:$False
Write-Host FSRM Share "$Path" using file Screen Template "$fileTemplateName" Deleted
}

# Removing FSRM File Screen Template if Allready Exist
$delScreentemplate= Get-FsrmFileScreenTemplate | Select Name | Where-Object {$_.Name -like "$fileTemplateName"} | Select -ExpandProperty Name
foreach ($Name in $delScreenTemplate) {
Remove-FsrmFileScreenTemplate $Name -Confirm:$False
Write-Host FSRM Screen Template  $Name using File Group Name $fileGroupName Deleted
}

# Removing File Group if allready exist
$delFSRMGroupName= Get-FsrmFileGroup | Select Name | Where-Object {$_.Name -like "$fileGroupName"} | Select -ExpandProperty Name
foreach ($Name in $delFSRMGroupName) {
Remove-FsrmFileGroup $Name -Confirm:$False
Write-Host FSRM File group  $Name  Deleted
}
# Creating FSRM File Group#
# Remove-FsrmFileGroup -Name "$fileGroupName" -Confirm:$false
Write-Host Creating FSRM File Group $fileGroupName
New-FsrmFileGroup -Name "$fileGroupName" -IncludePattern $ext_filter

# Creating FSRM File Template #
# You Can modify the Notification to add the command to execute in case of violation
#    -Notification $EventNotification,$commande    that will add $Commande to be started
Write-Host Creating FSRM File Template $fileTemplateName including $fileGroupName
New-FsrmFileScreenTemplate -Name "$fileTemplateName" -Active:$True -IncludeGroup "$fileGroupName" -Notification $EventNotification

# Creating FSRM File Screen #
foreach ($share in $drivesContainingShares) {
New-FsrmFileScreen -Path $share -Active:$true -Description "$fileScreenName" -IncludeGroup "$filegroupname" -Template "$fileTemplateName"
Write-Host Share File Screen $share based on $fileTemplateName for the extensions list group $fileGroupName has been created
}

# Keeping list to compare next #
#time with new one 
rm $wkdir\extensions.old
rm $wkdir\drivesbase.txt
rm $wkdir\extsbase.txt
cp $wkdir\extensions.txt $wkdir\extensions.old
rm $wkdir\extensions.txt
echo Finish

Exit 
