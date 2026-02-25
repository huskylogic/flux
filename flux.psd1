#
# flux.psd1 — Module Manifest
#

@{
    # Module identity
    ModuleVersion     = '0.1.0'
    GUID              = 'a3f1c2d4-8b5e-4f7a-9c3d-1e2f5a6b7c8d'
    Author            = 'Your Name'
    CompanyName       = ''
    Copyright         = '(c) 2025. MIT License.'
    Description       = 'Flux — a smarter winget wrapper for easier package discovery and scripting.'

    # Compatibility
    PowerShellVersion = '5.1'

    # Entry point
    RootModule        = 'flux.psm1'

    # Exports
    FunctionsToExport = @(
        'flux'
        'Install-FluxPackage'
        'Search-FluxPackage'
        'Uninstall-FluxPackage'
        'Get-FluxPackage'
    )
    CmdletsToExport   = @()
    VariablesToExport = @()
    AliasesToExport   = @()

    # PSGallery metadata
    PrivateData = @{
        PSData = @{
            Tags         = @('winget', 'package-manager', 'windows', 'cli')
            LicenseUri   = 'https://github.com/yourname/flux/blob/main/LICENSE'
            ProjectUri   = 'https://github.com/yourname/flux'
            ReleaseNotes = 'Initial release. Supports install, search, uninstall, and list.'
        }
    }
}
