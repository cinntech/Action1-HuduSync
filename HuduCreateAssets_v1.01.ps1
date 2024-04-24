<#
.SYNOPSIS
Creates a new computer asset in Hudu based on user input.

.DESCRIPTION
This script checks the PowerShell version, sets up the Hudu API, and allows the user to create a new computer asset within a specified company in Hudu.

.NOTES
Author: Wallace Cinnamon | CinnTech Ltd.
Version: 1.0
Creation Date: 2024-04-23
#>

# Helper function to convert secure string to plain text
function ConvertTo-PlainText {
    param ([securestring]$SecureString)
    $bstr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($SecureString)
    try {
        $plainText = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($bstr)
    }
    finally {
        [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)
    }
    return $plainText
}

# Check if running PowerShell 7 or higher
if ($PSVersionTable.PSVersion.Major -lt 7) {
    Write-Host "This script requires PowerShell 7 or higher." -ForegroundColor Red
    $pwshPath = Get-Command pwsh -ErrorAction SilentlyContinue
    if ($pwshPath) {
        $scriptPath = $PSCommandPath
        $runCommand = "pwsh -File `"$scriptPath`""
        Write-Host "You can try running this script with PowerShell 7 using the following command:" -ForegroundColor Yellow
        Write-Host $runCommand -ForegroundColor Yellow
        Write-Host "Press Enter to continue with PowerShell 7 or any other key to exit." -ForegroundColor Cyan
        $userInput = Read-Host
        if ($userInput -eq '') {
            & pwsh -File $scriptPath
            exit
        }
    } else {
        Write-Host "PowerShell 7 is not detected on this system. Do you want to open the download page for PowerShell 7? (Y/N)" -ForegroundColor Yellow
        $downloadConsent = Read-Host
        if ($downloadConsent -eq 'Y') {
            Start-Process "https://github.com/PowerShell/PowerShell/releases/latest"
        }
        Write-Host "Please install PowerShell 7 and rerun this script." -ForegroundColor Yellow
    }
    exit
}

# Import HuduAPI module, checking and installing if necessary
if (-not (Get-Module -ListAvailable -Name HuduAPI)) {
    Install-Module HuduAPI -Force
}
Import-Module HuduAPI

# Setup API key and Hudu base domain
$secureApiKey = Read-Host "Enter your Hudu API key" -AsSecureString
$apiKey = ConvertTo-PlainText -SecureString $secureApiKey
$HuduBaseDomain = Read-Host "Enter your Hudu base domain (e.g., https://your.hudu.domain) or press Enter to use 'https://cinntech.huducloud.com'"
if (-not $HuduBaseDomain) {
    $HuduBaseDomain = "https://cinntech.huducloud.com"
}
New-HuduAPIKey -ApiKey $apiKey
New-HuduBaseUrl -BaseUrl $HuduBaseDomain

# Default log file path and setup
$defaultLogPath = Join-Path -Path $PSScriptRoot -ChildPath "huduComputerAssetCreation.log"
$logPath = Read-Host "Enter path for the log file or press Enter to use default ($defaultLogPath)"
if (-not $logPath) {
    $logPath = $defaultLogPath
}

$logDirectory = Split-Path -Path $logPath -Parent
if (-not (Test-Path -Path $logDirectory)) {
    New-Item -ItemType Directory -Path $logDirectory -Force
}
Add-Content -Path $logPath -Value "$(Get-Date) - Script started"

# Main execution
try {
    $CompanyName = Read-Host "Enter the company name where the asset will be created"
    $Company = Get-HuduCompanies -Name $CompanyName
    if ($Company) {
        $AssetLayoutName = "Computer Assets"
        $Layout = Get-HuduAssetLayouts -Name $AssetLayoutName
        if (-not $Layout) {
            Write-Host "Creating new asset layout: $AssetLayoutName"
            $NewLayoutFields = @(
                @{label = 'Brand'; field_type = 'Text'},
                @{label = 'Model'; field_type = 'Text'},
                @{label = 'Memory'; field_type = 'Text'},
                @{label = 'Hard Drive Size'; field_type = 'Text'},
                @{label = 'Service Tag'; field_type = 'Text'},
                @{label = 'Operating System'; field_type = 'Text'},
                @{label = 'Warranty Expiration'; field_type = 'Date'}
            )
            New-HuduAssetLayout -Name $AssetLayoutName -Fields $NewLayoutFields -Icon "fas fa-laptop" -Color "red" -IconColor "blue" -IncludePasswords $False -IncludePhotos $False -IncludeComments $False -IncludeFiles $False
            $Layout = Get-HuduAssetLayouts -Name $AssetLayoutName
        }

        if ($Layout) {
            $AssetName = "TestPC"
            $AssetFields = @{
                'Brand'               = 'Lenovo'
                'Model'               = 'IdeaPad 3 15IAU7'
                'Memory'              = '12GB'
                'Hard Drive Size'     = '500GB'
                'Service Tag'         = 'PF4D8EGX'
                'Operating System'    = 'Windows 11 (23H2)'
                'Warranty Expiration' = '2024-04-01T00:00:00.000Z'
            }

            Write-Host "Creating new asset: $AssetName"
            $NewAsset = New-HuduAsset -Name $AssetName -CompanyId $Company.id -AssetLayoutId $Layout.id -Fields $AssetFields
            if ($NewAsset) {
                Write-Host "Asset created successfully under the company: $CompanyName" -ForegroundColor Green
                Add-Content -Path $logPath -Value "$(Get-Date) - Asset created successfully: $AssetName"
            } else {
                Write-Host "Failed to create asset: $AssetName" -ForegroundColor Red
                Add-Content -Path $logPath -Value "$(Get-Date) - Failed to create asset: $AssetName"
            }
        } else {
            Write-Host "Failed to create or retrieve asset layout: $AssetLayoutName" -ForegroundColor Red
            Add-Content -Path $logPath -Value "$(Get-Date) - Failed to retrieve asset layout: $AssetLayoutName"
        }
    } else {
        Write-Host "Company not found: $CompanyName" -ForegroundColor Red
        Add-Content -Path $logPath -Value "$(Get-Date) - Company not found: $CompanyName"
    }
} catch {
    Write-Error "An error occurred during script execution: $($_.Exception.Message)"
    Add-Content -Path $logPath -Value "$(Get-Date) - An error occurred: $($_.Exception.Message)"
}

Add-Content -Path $logPath -Value "$(Get-Date) - Script completed"
