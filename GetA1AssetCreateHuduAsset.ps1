<#
.SYNOPSIS
This script fetches endpoint details from the Action1 platform based on a company name entered by the user, which retrieves the corresponding organization ID from Hudu. It will then create these assets in Hudu for the same company name.

.DESCRIPTION
The script prompts the user for a Hudu API key, retrieves the corresponding Action1 organization ID from Hudu, and then retreives these from Action1 based on the A1 Org #. It will then put these assets into Hudu for the same client.

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

# Get-OrInstall Modules for Hudu and Action1
$modules = @("HuduAPI", "PSAction1")
foreach ($mod in $modules) {
    if (-not (Get-OrInstall-Module -ModuleName $mod)) {
        Write-Host "Critical error with module $mod, exiting script."
        exit
    }
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

# Function to get organization ID number (Action1 OrgID) from the company name in Hudu
function Get-OrganizationIdNumber {
    param([string]$companyName)

    $encodedCompanyName = [uri]::EscapeDataString($companyName)
    $uri = "$HuduBaseDomain/companies?name=$encodedCompanyName"    

    Write-Host "Attempting to retrieve Organization ID from URI: $uri"  # Debug statement
   
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

function Initialize-ActionOneEnvironment {
    param(
        [string]$ActionOneApiKey,
        [string]$ActionOneApiSecretKey,
        [string]$ActionOneOrgID,
        [string]$Region
    )
    try {
        # Simulated function call
        Set-Action1Region -Region $Region
        Set-Action1DefaultOrg -Org_ID $ActionOneOrgID
        Set-Action1Credentials -APIKey $ActionOneApiKey -Secret $ActionOneApiSecretKey
        Write-Output "Action1 environment setup complete."
    } catch {
        Write-Error "Action1 environment setup failed: $($_.Exception.Message)"
        exit
    }
}

# Function to initialize the Hudu environment
function Initialize-HuduEnvironment {
    param(
        [string]$HuduApiKeyPlainText,  
        [string]$HuduBaseDomain
    )

    try {
        New-HuduAPIKey -ApiKey $HuduApiKeyPlainText  
        New-HuduBaseUrl -BaseUrl $HuduBaseDomain
        Write-Output "Hudu environment setup complete."
    } catch {
        Write-Error "Hudu environment setup failed: $($_.Exception.Message)"
        exit
    }
}

# Function to perform Hudu API requests
function Invoke-HuduApiRequest {
    param (
        [string]$Endpoint,
        [string]$HuduApiKey
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

# Transforms SecureString to plain text using BSTR for secure handling and cleanup of sensitive data.
function ConvertTo-PlainText {
    param (
        [Parameter(Mandatory = $true)]
        [System.Security.SecureString]
        $SecureString
    )

    $bstr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($SecureString)
    try {
        $plainText = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($bstr)
    }
    finally {
        [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)
    }
    return $plainText
}

# Initializes logging by creating a log file directory and adding a start entry with an optional custom path.
function Initialize-Logging {
    [CmdletBinding()]
    param (
        [string]$LogFile = "$(Join-Path -Path $PSScriptRoot -ChildPath 'huduComputerAssetCreation.log')"
    )

    # Get user input for log file path or use the default
    $logPath = Read-Host "Enter path for the log file or press Enter to use default ($LogFile)"
    if (-not $logPath) {
        $logPath = $LogFile
    }

    # Ensure the directory for the log file exists
    $logDirectory = Split-Path -Path $logPath -Parent
    if (-not (Test-Path -Path $logDirectory)) {
        New-Item -ItemType Directory -Path $logDirectory -Force
    }

    # Start logging
    Add-Content -Path $logPath -Value "$(Get-Date) - Script started"
}

#############
# Uncomment the below to Initialize Logging. 
 Initialize-Logging
#############

# Define constants or configurable parameters at the start
$HuduBaseDomain = "https://cinntech.huducloud.com/api/v1//"
$Region = "NorthAmerica"

# Define headers
$headers = @{
    "x-api-key" = $HuduApiKey
    "Content-Type" = "application/json"
    "Accept" = "application/json"
}

# Prompt the user for the company name
$companyName= Read-Host -Prompt 'Enter the company name as it is Shown in Hudu'

#Setup Action1 Api
$secureActionOneApiKey = Read-Host "Enter your Action1 API key (starts with 'api-key-') for $companyName" -AsSecureString
$ActionOneApiKey = ConvertTo-PlainText -SecureString $secureActionOneApiKey

$secureActionOneApiSecretKey = Read-Host "Enter your Action1 API key Secret for $companyName" -AsSecureString
$ActionOneApiSecretKey = ConvertTo-PlainText -SecureString $secureActionOneApiSecretKey

# Setup Hudu Api
$secureHuduApiKey = Read-Host "Enter your Hudu API key" -AsSecureString
$HuduApiKey = ConvertTo-PlainText -SecureString $secureHuduApiKey

# Optionally override the base domain
$HuduBaseDomain = Read-Host "Enter your Hudu base domain (e.g., https://your.hudu.domain/api/v1) or press Enter to use default"
if (-not $HuduBaseDomain) {
    $HuduBaseDomain = "https://cinntech.huducloud.com/api/v1"
}

# Optionally override the Region
$Region = Read-Host "Enter your Action1 Region (e.g., NorthAmerica,Europe) or press Enter to use default"
if (-not $Region) {
    $Region = "NorthAmerica"
}

# ActionOneOrgID fetched 
$ActionOneOrgID = Get-OrganizationIdNumber -companyName $CompanyName
if (-not $ActionOneOrgID) {
    Write-Host "Unable to retrieve Organization ID, terminating script."
    exit
}

# Call the function to initialize the environment
try {
    Write-Host $ActionOneOrgID
    Initialize-HuduEnvironment -HuduApiKeyPlainText $HuduApiKey -BaseDomain $HuduBaseDomain
    Initialize-ActionOneEnvironment -ApiKey $ActionOneApiKey -Secret $ActionOneApiSecretKey -Region $Region -OrgID $ActionOneOrgID
 


    # Perform an HuduAPI request
    $response = Invoke-HuduApiRequest -Endpoint "/companies?name=$encodedCompanyName" -ApiKey $HuduApiKey
    if ($response) {
        Write-Host "Hudu API Request Successful: " -ForegroundColor Green
        Write-Output $response
    } else {
        Write-Host "Hudu API Request Failed or No Data Found."
    }
} catch {
    Write-Error "An unexpected error occurred: $($_.Exception.Message)"
}

## company name needs to be converted to company id - or not working right.




