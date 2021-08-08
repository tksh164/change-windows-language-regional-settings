function Get-JapaneseLangPackCabFile
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string] $DestinationFilePath
    )

    # Ref: Cannot configure a language pack for Windows Server 2019 Desktop Experience
    #      https://docs.microsoft.com/en-us/troubleshoot/windows-server/shell-experience/cannot-configure-language-pack-windows-server-desktop-experience
    $LANG_PACK_ISO_URI = 'https://software-download.microsoft.com/download/pr/17763.1.180914-1434.rs5_release_SERVERLANGPACKDVD_OEM_MULTI.iso'  # WS2019
    $request = [System.Net.HttpWebRequest]::Create($LANG_PACK_ISO_URI)
    $request.Method = 'GET'

    # Set the Japanese language pack CAB file data range.
    $OFFSET_TO_JP_LANG_CAB_FILE_IN_ISO_FILE = 1003644928
    $JP_LANG_CAB_FILE_SIZE = 62015873
    $request.AddRange('bytes', $OFFSET_TO_JP_LANG_CAB_FILE_IN_ISO_FILE, $OFFSET_TO_JP_LANG_CAB_FILE_IN_ISO_FILE + $JP_LANG_CAB_FILE_SIZE - 1)

    # Donwload the lang pack CAB file.
    $response = $request.GetResponse()
    $reader = New-Object -TypeName 'System.IO.BinaryReader' -ArgumentList $response.GetResponseStream()
    $contents = $reader.ReadBytes($response.ContentLength)
    $reader.Dispose()

    # Save the lang pack CAB file.
    $fileStream = [System.IO.File]::Create($DestinationFilePath)
    $fileStream.Write($contents, 0, $contents.Length)
    $fileStream.Dispose()

    # Verify integrity to the downloaded lang pack CAB file.
    $JP_LANG_CAB_FILE_HASH = 'B562ECD51AFD32DB6E07CB9089691168C354A646'
    $fileHash = Get-FileHash -Algorithm SHA1 -LiteralPath $DestinationFilePath
    if ($fileHash.Hash -ne $JP_LANG_CAB_FILE_HASH) {
        throw ('"{0}" is corrupted. The download was may failed.') -f $DestinationFilePath
    }
}

function Copy-LanguageSttingsToDefaultAndSystemAccount
{
    [CmdletBinding()]
    param ()

    # Ref: How to Automate Regional and Language settings in Windows Vista, Windows Server 2008, Windows 7 and in Windows Server 2008 R2
    #      https://docs.microsoft.com/en-us/troubleshoot/windows-client/deployment/automate-regional-language-settings
    $XML_FILE_CONTENT = @'
<gs:GlobalizationServices xmlns:gs="urn:longhornGlobalizationUnattend">
    <gs:UserList>
        <gs:User UserID="Current" CopySettingsToDefaultUserAcct="true" CopySettingsToSystemAcct="true"/> 
    </gs:UserList>
</gs:GlobalizationServices>
'@

    # Create a XML file.
    $xmlFileFilePath = Join-Path -Path $env:TEMP -ChildPath ((New-Guid).Guid + '.xml')
    Set-Content -LiteralPath $xmlFileFilePath -Encoding UTF8 -Value $XML_FILE_CONTENT

    # Copy the current user language settings to default user account and system user account.
    $procStartInfo = New-Object -TypeName 'System.Diagnostics.ProcessStartInfo' -ArgumentList 'C:\Windows\System32\control.exe', ('intl.cpl,,/f:"{0}"' -f $xmlFileFilePath)
    $procStartInfo.UseShellExecute = $false
    $procStartInfo.WindowStyle = [System.Diagnostics.ProcessWindowStyle]::Minimized
    $proc = [System.Diagnostics.Process]::Start($procStartInfo)
    $proc.WaitForExit()

    # Delete the XML file.
    Remove-Item -LiteralPath $xmlFileFilePath -Force
}


# Download the lang pack CAB file.
$langPackFilePath = Join-Path -Path $env:TEMP -ChildPath 'Microsoft-Windows-Server-Language-Pack_x64_ja-jp.cab'
Get-JapaneseLangPackCabFile -DestinationFilePath $langPackFilePath

# Add the language pack.
Add-WindowsPackage -Online -NoRestart -PackagePath $langPackFilePath

# Delete the lang pack CAB file.
Remove-Item -LiteralPath $langPackFilePath -Force

# Add the Japanese language related capabilities.
Add-WindowsCapability -Online -Name 'Language.Basic~~~ja-JP~0.0.1.0'
Add-WindowsCapability -Online -Name 'Language.Fonts.Jpan~~~und-JPAN~0.0.1.0'
Add-WindowsCapability -Online -Name 'Language.Handwriting~~~ja-JP~0.0.1.0'
Add-WindowsCapability -Online -Name 'Language.OCR~~~ja-JP~0.0.1.0'
Add-WindowsCapability -Online -Name 'Language.Speech~~~ja-JP~0.0.1.0'
Add-WindowsCapability -Online -Name 'Language.TextToSpeech~~~ja-JP~0.0.1.0'

# Set the preferred language for the current user account.
$langList = Get-WinUserLanguageList
$langList.Insert(0, 'ja')
Set-WinUserLanguageList -LanguageList $langList -Force

# Enable the dynamically setting the culture based on the Windows display language for the current user.
# This setting doesn't need change because the default value is the same.
#Set-WinCultureFromLanguageListOptOut -OptOut $false

# Set the language bar type and mode for the current user account.
# This setting doesn't need change because the default value is the same.
#Set-WinLanguageBarOption -UseLegacySwitchMode:$false -UseLegacyLanguageBar:$false

# Override the default input method to 'ja-JP: Microsoft IME' for the current user account.
# This setting doesn't need change because the default value is the same.
# Ref: Default Input Profiles (Input Locales) in Windows
#      https://docs.microsoft.com/en-us/windows-hardware/manufacture/desktop/default-input-locales-for-windows-language-packs
#Set-WinDefaultInputMethodOverride -InputTip '0411:{03B5835F-F03C-411B-9CE2-AA23E1171E36}{A76C93D9-5523-4E90-AAFA-4DB112F9AC76}'

# Use the HTTP Accept Language list based on the language list for the current user account.
# This setting doesn't need change because the default value is the same.
#Set-WinAcceptLanguageFromLanguageListOptOut -OptOut $false

# Set the home location for the current user account.
# Ref: Table of Geographical Locations
#      https://docs.microsoft.com/en-us/windows/win32/intl/table-of-geographical-locations
Set-WinHomeLocation -GeoId 0x7a  # Japan

# Set the time zone to the Tokyo Standard Time.
Set-TimeZone -Id 'Tokyo Standard Time'

# Set the system locale for the current computer.
Set-WinSystemLocale -SystemLocale ja-JP

# The language pack installation and system locale change needs the restart for take effect.
Restart-Computer

# Override the Windows UI language for the current user account.
Set-WinUILanguageOverride -Language ja-JP

# Copy the current user language settings to default user account and system user account.
Copy-LanguageSttingsToDefaultAndSystemAccount

# The Windows UI language change needs the restart for take effect.
Restart-Computer
