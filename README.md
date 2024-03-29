# Change the Windows language & regional settings

This scripts demonstrate that change the Windows language options and region settings.

You need run the script line by line because the script has two phases that include the system reboots.

Phase 1:

1. Download the Japanese language pack.
2. Install the Japanese language pack to the system.
3. Install the Japanese language related capabilities to the system.
4. Set the time zone for the system.
5. Restart the system.

Phase 2:

1. Set the current user's language options and copy it to the default user account and system account. Also, set the system locale.
2. Restart the system.

## References

- Language pack download

    - Windows Server 2022

        You can get the Windows Server 2022 Language Pack ISO file from the link in [Windows Server 2022 - Evaluation Center](https://www.microsoft.com/en-us/evalcenter/evaluate-windows-server-2022). The script uses the link URI. The ISO file contains all language pack CAB files.

        > Download this **ISO**.

    - Windows Server 2019

        You can get the Windows Server 2019 Language Pack ISO file from the link in [Cannot configure a language pack for Windows Server 2019 Desktop Experience](https://docs.microsoft.com/en-us/troubleshoot/windows-server/shell-experience/cannot-configure-language-pack-windows-server-desktop-experience). The script uses the link URI. The ISO file contains all language pack CAB files.

        > 1. Download an ISO image that contains the language packs **here**.

- Language options configuration

    The script uses Multilingual User Interface XML file for language options configuration. That explained in [Guide to Windows Vista Multilingual User Interface](https://docs.microsoft.com/en-us/previous-versions/windows/it-pro/windows-vista/cc721887(v=ws.10)).

- Input Profiles (Input Locales)

    You can find your language's Input Profile in [Default Input Profiles (Input Locales) in Windows](https://docs.microsoft.com/en-us/windows-hardware/manufacture/desktop/default-input-locales-for-windows-language-packs).

- Geographical Locations

    You can find your Geographical Location in [Table of Geographical Locations](https://docs.microsoft.com/en-us/windows/win32/intl/table-of-geographical-locations).

- Cultures

    You can get all cultures by the following PowerShell code. It's use for `UserLocale` and `SystemLocale`.

    ```powershell
    [System.Globalization.CultureInfo]::GetCultures([System.Globalization.CultureTypes]::AllCultures).Name
    ```

- Time zones

    You can get all available time zones by the following PowerShell code.

    ```powershell
    Get-TimeZone -ListAvailable
    ```

## Notes

- Sometimes `Add-WindowsCapability` cmdlet failed with the following message. You can simply retry the command to resolve it.

    ```
    Add-WindowsCapability : The data area passed to a system call is too small.
    At line:1 char:1
    + Add-WindowsCapability -Online -Name 'Language.Basic~~~ja-JP~0.0.1.0'  ...
    + ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
        + CategoryInfo          : NotSpecified: (:) [Add-WindowsCapability], COMException
        + FullyQualifiedErrorId : Microsoft.Dism.Commands.AddWindowsCapabilityCommand
    ```

## Related repo

- [Change the Windows language options and regional settings using the DSC extension](https://github.com/tksh164/azure-demo-scripts-templates/tree/master/arm-templates/win-lang-region-config)
    - The DSC extension implementation of the script for Azure VMs.

## License

Copyright (c) 2021-present Takeshi Katano. All rights reserved. This software is released under the [MIT License](https://github.com/tksh164/windows-language-culture-change-script/blob/master/LICENSE).

Disclaimer: The codes stored herein are my own personal codes and do not related my employer's any way.
