# Adding FsLogix unc path configuration to Registry
# This must be run with Elevated Permissions to modify registry

$AssemblyFullName = 'System.Windows.Forms, Version=4.0.0.0, Culture=neutral, PublicKeyToken=b77a5c561934e089'
$Assembly = [System.Reflection.Assembly]::Load($AssemblyFullName)

Function Get-Folder($initialDirectory="")
{
    $OpenFileDialog = [System.Windows.Forms.OpenFileDialog]::new()
    $OpenFileDialog.AddExtension = $false
    $OpenFileDialog.CheckFileExists = $false
    $OpenFileDialog.DereferenceLinks = $true
    $OpenFileDialog.Filter = "Folders|`n"
    $OpenFileDialog.Multiselect = $false
    $OpenFileDialog.Title = "Select folder"
    $OpenFileDialogType = $OpenFileDialog.GetType()
    
    $FileDialogInterfaceType = $Assembly.GetType('System.Windows.Forms.FileDialogNative+IFileDialog')
    $IFileDialog = $OpenFileDialogType.GetMethod('CreateVistaDialog',@('NonPublic','Public','Static','Instance')).Invoke($OpenFileDialog,$null)
    $null = $OpenFileDialogType.GetMethod('OnBeforeVistaDialog',@('NonPublic','Public','Static','Instance')).Invoke($OpenFileDialog,$IFileDialog) | Out-Null

    [uint32]$PickFoldersOption = $Assembly.GetType('System.Windows.Forms.FileDialogNative+FOS').GetField('FOS_PICKFOLDERS').GetValue($null)
    $FolderOptions = $OpenFileDialogType.GetMethod('get_Options',@('NonPublic','Public','Static','Instance')).Invoke($OpenFileDialog,$null) -bor $PickFoldersOption
    $null = $FileDialogInterfaceType.GetMethod('SetOptions',@('NonPublic','Public','Static','Instance')).Invoke($IFileDialog,$FolderOptions)  | Out-Null
    $VistaDialogEvent = [System.Activator]::CreateInstance($AssemblyFullName,'System.Windows.Forms.FileDialog+VistaDialogEvents',$false,0,$null,$OpenFileDialog,$null,$null).Unwrap()
    [uint32]$AdviceCookie = 0
    $AdvisoryParameters = @($VistaDialogEvent,$AdviceCookie)
    $AdviseResult = $FileDialogInterfaceType.GetMethod('Advise',@('NonPublic','Public','Static','Instance')).Invoke($IFileDialog,$AdvisoryParameters)
    $AdviceCookie = $AdvisoryParameters[1]
    $Result = $FileDialogInterfaceType.GetMethod('Show',@('NonPublic','Public','Static','Instance')).Invoke($IFileDialog,[System.IntPtr]::Zero)
    $null = $FileDialogInterfaceType.GetMethod('Unadvise',@('NonPublic','Public','Static','Instance')).Invoke($IFileDialog,$AdviceCookie)  | Out-Null

    if ($Result -eq [System.Windows.Forms.DialogResult]::OK) 
    {
        $FileDialogInterfaceType.GetMethod('GetResult',@('NonPublic','Public','Static','Instance')).Invoke($IFileDialog,$null)
    }

    Write-Output $OpenFileDialog.FileName
}

$fsLogixProfilePath = Get-Folder
$fsLogixProfilePath

$enabledPropertyKey = New-Object System.Object
$enabledPropertyKey | Add-Member -type NoteProperty -Name "Name" -Value "Enabled"
$enabledPropertyKey | Add-Member -type NoteProperty -Name "Type" -Value "DWORD"
$enabledPropertyKey | Add-Member -type NoteProperty -Name "Value" -Value "1"

$deleteLocalProfilePropertyKey = New-Object System.Object
$deleteLocalProfilePropertyKey | Add-Member -type NoteProperty -Name "Name" -Value "DeleteLocalProfileWhenVHDShouldApply"
$deleteLocalProfilePropertyKey | Add-Member -type NoteProperty -Name "Type" -Value "DWORD"
$deleteLocalProfilePropertyKey | Add-Member -type NoteProperty -Name "Value" -Value "1"

$vhdLocationsPropertyKey = New-Object System.Object
$vhdLocationsPropertyKey | Add-Member -type NoteProperty -Name "Name" -Value "VHDLocations"
$vhdLocationsPropertyKey | Add-Member -type NoteProperty -Name "Type" -Value "MultiString"
$vhdLocationsPropertyKey | Add-Member -type NoteProperty -Name "Value" -Value @($fsLogixProfilePath)

$regKeys = @()
$regKeys += $enabledPropertyKey
$regKeys += $deleteLocalProfilePropertyKey
$regKeys += $vhdLocationsPropertyKey

# $regKeys

# Computer\HKEY_LOCAL_MACHINE\software\FSLogix\Profiles
$fsLogixRegistryPath = "HKLM:\SOFTWARE\FSLogix\Profiles"

Write-Host "Verifying Registry Key: $fsLogixRegistryPath" -ForegroundColor Magenta

# if not exist, then create key
if(!(Test-Path $fsLogixRegistryPath)) {
    New-Item -Path $fsLogixRegistryPath -Force | Out-Null
    Write-Host "Added new Registry Key: " + $fsLogixRegistryPath -ForegroundColor Cyan    
}

foreach($key in $regKeys)
{
    New-ItemProperty -Path $fsLogixRegistryPath -Name $key.Name -Value $key.Value -PropertyType $key.Type -Force | Out-Null
}

foreach($key in $regKeys)
{
    Get-ItemProperty -Path $fsLogixRegistryPath -Name $key.Name
}

Write-Host "All FSLogix Properties added/updated. " -ForegroundColor Green    