<#
.SYNOPSIS
This script fetches endpoint details from the Action1 platform based on a company name entered by the user,
which retrieves the corresponding organization ID from Hudu. It will then create these assets in Hudu for the same company name.

.DESCRIPTION
The script prompts the user for a Hudu API key, retrieves the corresponding Action1 organization ID from Hudu,
and then retrieves these from Action1 based on the A1 Org #. It will then put these assets into Hudu for the same client.

.NOTES
Author: Wallace Cinnamon | CinnTech
Version: 1.0
Creation Date: 2024-04-24
#>

function Get-OrInstall-Module {
    param([string]$ModuleName)
    $module = Get-Module -ListAvailable -Name $ModuleName
    if (-not $module) {
        try {
            Write-Output "Module '$ModuleName' is not installed. Trying to install..."
            Install-Module -Name $ModuleName -Force -Scope CurrentUser
            $module = Get-Module -ListAvailable -Name $ModuleName
            if (-not $module) {
                Write-Error "Installation of '$ModuleName' failed."
                return $false
            }
            Write-Output "Module '$ModuleName' installed."
        } catch {
            Write-Error "Failed to install '$ModuleName': $($_.Exception.Message)"
            return $false
        }
    } else {
        Write-Output "Module '$ModuleName' already installed."
    }
    try {
        Import-Module -Name $ModuleName
        Write-Output "Module '$ModuleName' loaded successfully."
        return $true
    } catch {
        Write-Error "Failed to load module '$ModuleName': $($_.Exception.Message)"
        return $false
    }
}

$modules = @("HuduAPI", "PSAction1")
foreach ($mod in $modules) {
    if (-not (Get-OrInstall-Module -ModuleName $mod)) {
        Write-Host "Critical error with module $mod, exiting script."
        exit
    }
}

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



function Initialize-HuduEnvironment {
    param(
        [string]$ApiKeyPlainText,
        [string]$HuduBaseDomain
    )
    try {
        # Assume New-HuduAPIKey and New-HuduBaseUrl are valid commands or placeholders for your actual functionality
        New-HuduAPIKey -ApiKey $ApiKeyPlainText
        New-HuduBaseUrl -BaseUrl $HuduBaseDomain
        Write-Output "Hudu environment setup complete."
    } catch {
        Write-Error "Hudu environment setup failed: $($_.Exception.Message)"
        exit
    }
}

function Initialize-Action1Environment {
    param([string]$ApiKey, [string]$Secret, [string]$OrgID)
    Set-Action1Region -Region $Region
    Set-Action1DefaultOrg -Org_ID $OrgID
    try {
        Set-Action1Credentials -APIKey $ApiKey -Secret $Secret
        Write-Output "Action1 API setup complete."
    } catch {
        Write-Error "Action1 API setup failed: $($_.Exception.Message)"
        exit
    }
}


function Get-OrganizationIdNumber {
    param([string]$companyName, [hashtable]$headers,[string]$HuduBaseDomain)
    $encodedCompanyName = [uri]::EscapeDataString($companyName)
    $uri = "$HuduBaseDomain/companies?name=$encodedCompanyName"
    
    #Debut Only
    # Write-Host "Making API Request to URI: $uri with headers: $($headers | Out-String)"
    try {
        $response = Invoke-RestMethod -Uri $uri -Method Get -Headers $headers
        if ($response.companies -and $response.companies.Count -gt 0) {
            Write-Host "Organization ID retrieved: $($response.companies[0].id_number)"
            return $response.companies[0].id_number
        } else {
            Write-Host "No company found with the name '$companyName'. Please verify the name and try again."
            return $null
        }
    } catch {
        Write-Host "An error occurred while trying to retrieve the Organization ID: $($_.Exception.Message)"
        return $null
    }
}

function Invoke-HuduApiRequest {
    param (
        [string]$Endpoint,
        [string]$HuduApiKey,
        [hashtable]$Headers
    )
    $uri = "$HuduBaseDomain$Endpoint"
    try {
        $response = Invoke-RestMethod -Uri $uri -Method Get -Headers $headers
        return $response
    } catch {
        Write-Host "Error during API request: $($_.Exception.Message)"
        return $null
    }
}

# Use this function to convert SecureString to plain text securely
function ConvertTo-PlainText {
    param (
        [System.Security.SecureString]$SecureString
    )
    $bstr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($SecureString)
    try {
        $plainText = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($bstr)
    } finally {
        [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)
    }
    if ([string]::IsNullOrWhiteSpace($plainText)) {
        Write-Error "Converted text is null or empty."
        exit
    }
    return $plainText
}

function Initialize-Logging {
    [CmdletBinding()]
    param (
        [string]$LogFile = "$(Join-Path -Path $PSScriptRoot -ChildPath 'huduComputerAssetCreation.log')"
    )
    $logPath = Read-Host "Enter path for the log file or press Enter to use default ($LogFile)"
    if (-not $logPath) {
        $logPath = $LogFile
    }
    $logDirectory = Split-Path -Path $logPath -Parent
    if (-not (Test-Path -Path $logDirectory)) {
        New-Item -ItemType Directory -Path $logDirectory -Force
    }
    Add-Content -Path $logPath -Value "$(Get-Date) - Script started"
}

# Initialize Logging
#Initialize-Logging

# Define constants or configurable parameters at the start
$HuduBaseDomain = "https://cinntech.huducloud.com/api/v1/"
$Region = "NorthAmerica"


$companyName = Read-Host -Prompt 'Enter the company name as it is Shown in Hudu'
$secureActionOneApiKey = Read-Host "Enter your Action1 API key (starts with 'api-key-') for $companyName" -AsSecureString
$secureActionOneApiSecretKey = Read-Host "Enter your Action1 API key Secret for $companyName" -AsSecureString
$secureHuduApiKey = Read-Host "Enter your Hudu API key" -AsSecureString
#

$ActionOneApiKey = ConvertTo-PlainText -SecureString $secureActionOneApiKey
$ActionOneApiSecretKey = ConvertTo-PlainText -SecureString $secureActionOneApiSecretKey
$HuduApiKey = ConvertTo-PlainText -SecureString $secureHuduApiKey


$HuduBaseDomain = Read-Host "Enter your Hudu base domain (e.g., https://your.hudu.domain/api/v1) or press Enter to use default"

if (-not $HuduBaseDomain) {
    $HuduBaseDomain = "https://cinntech.huducloud.com/api/v1/"
}

$HuduApiKey = ConvertTo-PlainText -SecureString $secureHuduApiKey

$headers = @{
    "x-api-key" = $HuduApiKey
    "Content-Type" = "application/json"
    "Accept" = "application/json"
}

$Region = Read-Host "Enter your Action1 Region (e.g., NorthAmerica,Europe) or press Enter to use default"
if (-not $Region) {
    $Region = "NorthAmerica"
}

#Initialize-HuduEnvironment -HuduApiKeyPlainText $HuduApiKey -HuduBaseDomain $HuduBaseDomain

$ActionOneOrgID = Get-OrganizationIdNumber -companyName $companyName -headers $headers -HuduBaseDomain $HuduBaseDomain
if (-not $ActionOneOrgID) {
    Write-Host "Unable to retrieve Organization ID, terminating script."
    exit
}
## Debug Only
#Write-Host $ActionOneOrgID
#Write-Host $ActionOneApiKey
#Write-Host $ActionOneApiSecretKey

Initialize-Action1Environment -ApiKey $ActionOneApiKey -Secret $ActionOneApiSecretKey -OrgID $ActionOneOrgID -Region $Region

#Get-Action1 -Query Endpoints | select -First 1

try {
#Get Endpoints
$endpoints = Get-Action1 -Query "Endpoints"
$endpointDetails = [System.Collections.Generic.List[object]]::new()
foreach ($endpoint in $endpoints) {
    $details = [PSCustomObject]@{
        Name = $endpoint.name
        Brand = if ([string]::IsNullOrWhiteSpace($endpoint.manufacturer)) { "Other" } else { $endpoint.manufacturer }
        HardDriveSize = $endpoint.disk
        ServiceTag = $endpoint.serial
        Memory = $endpoint.RAM
        OperatingSystem = $endpoint.OS
    }
    $endpointDetails.Add($details)
    Write-Output "Endpoint: $($details.Name)"
    $details | Format-List *
}
$endpointDetails | Export-Csv "EndpointDetails.csv" -NoTypeInformation
Write-Output "Endpoint details exported successfully."
} catch {
Write-Error "An error occurred during script execution: $($_.Exception.Message)"
}

