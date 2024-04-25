<#
.SYNOPSIS
Fetches endpoint details from the Action1 platform based on company names in Hudu.

.DESCRIPTION
The script prompts the user for a company name and uses the Hudu API to fetch the corresponding organization ID. It then uses this ID to set up the Action1 environment and retrieve endpoint details.

.NOTES
Author: Wallace Cinnamon | CinnTech Ltd.
Version: 1.2
Creation Date: 2024-04-23
#>

# Configuration and defaults


# Function to get organization ID by company name from Hudu
function Get-OrganizationId {
    param([string]$companyName)

    $encodedCompanyName = [uri]::EscapeDataString($companyName)
    $uri = "$HuduBaseUri/companies?name=$encodedCompanyName"
    
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
        Write-Host "An error occurred: $($_.Exception.Message)"
        return $null
    }
}

# Function to ensure and load required modules
function Get-OrInstall-Module {
    param([string]$ModuleName)
    $module = Get-Module -ListAvailable -Name $ModuleName
    if (-not $module) {
        try {
            Write-Output "Module '$ModuleName' is not installed. Trying to install..."
            Install-Module -Name $ModuleName -Force -Scope CurrentUser
            Write-Output "Module '$ModuleName' installed."
        } catch {
            Write-Error "Failed to install '$ModuleName': $($_.Exception.Message)"
            exit
        }
    } else {
        Write-Output "Module '$ModuleName' already installed."
    }
    Import-Module -Name $ModuleName
}

# Function to setup the Action1 environment
function Initialize-Action1Environment {
    param([string]$ApiKey, [string]$Secret, [string]$OrgID)
    Set-Action1Region -Region $Region
    Set-Action1DefaultOrg -Org_ID $OrgID
    try {
        Set-Action1Credentials -APIKey $ApiKey -Secret $Secret
        Write-Output "API setup complete."
    } catch {
        Write-Error "API setup failed: $($_.Exception.Message)"
        exit
    }
}

# Securely reading sensitive information
function Read-SecureInput($prompt) {
    $secureString = Read-Host -Prompt $prompt -AsSecureString
    $BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($secureString)
    try {
        $unsecureString = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
    }
    finally {
        [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($BSTR)
    }
    return $unsecureString
}

$HuduBaseUri = "https://cinntech.huducloud.com/api/v1/"

$Region = "NorthAmerica"

# Main script execution
try {
    $HuduApiKey = Read-SecureInput "Please enter your Hudu API key"
    $headers = @{
        "x-api-key" = $HuduApiKey
        "Content-Type" = "application/json"
        "Accept" = "application/json"
    }

    $UserCompanyName = Read-Host "Please enter the name of the company exactly as it is in Hudu"
    $ActionOneOrgID = Get-OrganizationId -companyName $UserCompanyName
    if (-not $ActionOneOrgID) {
        Write-Host "Unable to retrieve Organization ID, terminating script."
        exit
    }

    $moduleName = "PSAction1"
    Get-OrInstall-Module -ModuleName $moduleName

    $ApiKey = Read-SecureInput "Please enter your Action1 API-KEY (starts with api-key) for '$UserCompanyName'"
    $ApiSecretKey = Read-SecureInput "Please enter your Action1 API secret for '$UserCompanyName'"
    Initialize-Action1Environment -ApiKey $ApiKey -Secret $ApiSecretKey -OrgID $ActionOneOrgID

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
