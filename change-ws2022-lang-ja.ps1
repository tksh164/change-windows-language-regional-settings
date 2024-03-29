function Invoke-LanguagePackCabFileDownload
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string] $LangPackIsoUri,

        [Parameter(Mandatory = $true)]
        [long] $OffsetToCabFileInIsoFile,

        [Parameter(Mandatory = $true)]
        [long] $CabFileSize,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string] $CabFileHash,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string] $DestinationFilePath
    )

    $request = [System.Net.HttpWebRequest]::Create($LangPackIsoUri)
    $request.Method = 'GET'

    # Set the language pack CAB file data range.
    $request.AddRange('bytes', $OffsetToCabFileInIsoFile, $OffsetToCabFileInIsoFile + $CabFileSize - 1)

    # Donwload the language pack CAB file.
    $response = $request.GetResponse()
    $reader = New-Object -TypeName 'System.IO.BinaryReader' -ArgumentList $response.GetResponseStream()
    $fileStream = [System.IO.File]::Create($DestinationFilePath)
    $contents = $reader.ReadBytes($response.ContentLength)
    $fileStream.Write($contents, 0, $contents.Length)
    $fileStream.Dispose()
    $reader.Dispose()
    $response.Close()
    $response.Dispose()

    # Verify integrity of the downloaded language pack CAB file.
    $fileHash = Get-FileHash -Algorithm SHA1 -LiteralPath $DestinationFilePath
    if ($fileHash.Hash -ne $CabFileHash) {
        throw ('The file hash of the language pack CAB file "{0}" is not match to expected value. The download was may failed.') -f $DestinationFilePath
    }
}

function Set-LanguageOptions
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string] $UserLocale,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string] $InputLanguageID,

        [Parameter(Mandatory = $true)]
        [int] $LocationGeoId,

        [Parameter(Mandatory = $true)]
        [bool] $CopySettingsToSystemAccount,

        [Parameter(Mandatory = $true)]
        [bool] $CopySettingsToDefaultUserAccount,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string] $SystemLocale
    )

    # Reference:
    # - Guide to Windows Vista Multilingual User Interface
    #   https://docs.microsoft.com/en-us/previous-versions/windows/it-pro/windows-vista/cc721887(v=ws.10)
    $xmlFileContentTemplate = @'
<gs:GlobalizationServices xmlns:gs="urn:longhornGlobalizationUnattend">
    <gs:UserList>
        <gs:User UserID="Current" CopySettingsToSystemAcct="{0}" CopySettingsToDefaultUserAcct="{1}"/>
    </gs:UserList>
    <gs:UserLocale>
        <gs:Locale Name="{2}" SetAsCurrent="true"/>
    </gs:UserLocale>
    <gs:InputPreferences>
        <gs:InputLanguageID Action="add" ID="{3}" Default="true"/>
    </gs:InputPreferences>
    <gs:MUILanguagePreferences>
        <gs:MUILanguage Value="{2}"/>
        <gs:MUIFallback Value="en-US"/>
    </gs:MUILanguagePreferences>
    <gs:LocationPreferences>
        <gs:GeoID Value="{4}"/>
    </gs:LocationPreferences>
    <gs:SystemLocale Name="{5}"/>
</gs:GlobalizationServices>
'@

    # Create the XML file content.
    $fillValues = @(
        $CopySettingsToSystemAccount.ToString().ToLowerInvariant(),
        $CopySettingsToDefaultUserAccount.ToString().ToLowerInvariant(),
        $UserLocale,
        $InputLanguageID,
        $LocationGeoId,
        $SystemLocale
    )
    $xmlFileContent = $xmlFileContentTemplate -f $fillValues

    Write-Verbose -Message ('MUI XML: {0}' -f $xmlFileContent)

    # Create a new XML file and set the content.
    $xmlFileFilePath = Join-Path -Path $env:TEMP -ChildPath ((New-Guid).Guid + '.xml')
    Set-Content -LiteralPath $xmlFileFilePath -Encoding UTF8 -Value $xmlFileContent

    # Copy the current user language settings to the default user account and system user account.
    $procStartInfo = New-Object -TypeName 'System.Diagnostics.ProcessStartInfo' -ArgumentList 'C:\Windows\System32\control.exe', ('intl.cpl,,/f:"{0}"' -f $xmlFileFilePath)
    $procStartInfo.UseShellExecute = $false
    $procStartInfo.WindowStyle = [System.Diagnostics.ProcessWindowStyle]::Minimized
    $proc = [System.Diagnostics.Process]::Start($procStartInfo)
    $proc.WaitForExit()
    $proc.Dispose()

    # Delete the XML file.
    Remove-Item -LiteralPath $xmlFileFilePath -Force
}

# Download the language pack CAB file for Japanese.
#
# Reference:
# - Windows Server 2022 - Evaluation Center
#   https://www.microsoft.com/en-us/evalcenter/evaluate-windows-server-2022
$langPackFilePath = Join-Path -Path $env:TEMP -ChildPath 'Microsoft-Windows-Server-Language-Pack_x64_ja-jp.cab'
$params = @{
    LangPackIsoUri           = 'https://software-static.download.prss.microsoft.com/pr/download/20348.1.210507-1500.fe_release_amd64fre_SERVER_LOF_PACKAGES_OEM.iso'
    OffsetToCabFileInIsoFile = 0x107d35800L
    CabFileSize              = 54130307
    CabFileHash              = '298667B848087EA1377F483DC15597FD5F38A492'
    DestinationFilePath      = $langPackFilePath
}
Invoke-LanguagePackCabFileDownload @params -Verbose

# Install the language pack.
Add-WindowsPackage -Online -NoRestart -PackagePath $langPackFilePath -Verbose

# Delete the language pack CAB file.
Remove-Item -LiteralPath $langPackFilePath -Force -Verbose

# Install the Japanese language related capabilities.
Add-WindowsCapability -Online -Name 'Language.Basic~~~ja-JP~0.0.1.0' -Verbose
Add-WindowsCapability -Online -Name 'Language.Fonts.Jpan~~~und-JPAN~0.0.1.0' -Verbose
Add-WindowsCapability -Online -Name 'Language.OCR~~~ja-JP~0.0.1.0' -Verbose
Add-WindowsCapability -Online -Name 'Language.Handwriting~~~ja-JP~0.0.1.0' -Verbose   # Optional
Add-WindowsCapability -Online -Name 'Language.Speech~~~ja-JP~0.0.1.0' -Verbose        # Optional
Add-WindowsCapability -Online -Name 'Language.TextToSpeech~~~ja-JP~0.0.1.0' -Verbose  # Optional

# Set the time zone for the current computer.
Set-TimeZone -Id 'Tokyo Standard Time' -Verbose

# Restart the system to take effect the language pack installation.
Restart-Computer

# Set the current user's language options and copy it to the default user account and system account. Also, set the system locale.
#
# References:
# - Default Input Profiles (Input Locales) in Windows
#   https://docs.microsoft.com/en-us/windows-hardware/manufacture/desktop/default-input-locales-for-windows-language-packs
# - Table of Geographical Locations
#   https://docs.microsoft.com/en-us/windows/win32/intl/table-of-geographical-locations
$params = @{
    UserLocale                       = 'ja-JP'
    InputLanguageID                  = '0411:{03B5835F-F03C-411B-9CE2-AA23E1171E36}{A76C93D9-5523-4E90-AAFA-4DB112F9AC76}'
    LocationGeoId                    = 122  # Japan
    CopySettingsToSystemAccount      = $true
    CopySettingsToDefaultUserAccount = $true
    SystemLocale                     = 'ja-JP'
}
Set-LanguageOptions @params -Verbose

# Restart the system to take effect changes.
Restart-Computer
