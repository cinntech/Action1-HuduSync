<#
.SYNOPSIS
Automates the creation of folders in a specified Hudu company based on user input.

.DESCRIPTION
Prompts for an API key and company name in Hudu, retrieves the company ID, and creates predefined folders to organize various types of documentation and data.

.PARAMETER apiKey
API key used for authentication with the Hudu API.

.PARAMETER userCompanyName
Exact name of the company in Hudu as it should be input by the user.

.EXAMPLE
PS> .\CreateHuduFolders.ps1
Runs the script, prompting for API key and company name to proceed with folder creation.

.AUTHOR
Wallace Cinnamon | CinnTech Ltd.
Contact: wallace@cinntech.com

.VERSION
1.2 Updated for secure API key handling and improved error handling.
1.3 Updated for Approved verbs.

.NOTES
Requires appropriate permissions to access the Hudu API and manage folders within the specified company.

.LINK
Documentation for Hudu API: https://api.hudu.com/
#>

# Securely prompt for the API key
function Get-SecureApiKey {
    $secureApiKey = Read-Host "Please enter your Hudu API key" -AsSecureString
    $bstr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($secureApiKey)
    try {
        [System.Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr)
    }
    finally {
        [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)
    }
}

$apiKey = Get-SecureApiKey

# Define API Base URL and set up headers for API request
$baseUri = "https://cinntech.huducloud.com/api/v1/"
$headers = @{
    "x-api-key" = $apiKey
    "Content-Type" = "application/json"
    "Accept" = "application/json"
}

# Prompt user to enter the company name and URL encode it
$userCompanyName = Read-Host "Please enter the name of the company exactly as it is in Hudu"
$encodedCompanyName = [uri]::EscapeDataString($userCompanyName)

# Function to get the company ID by its name
function Get-CompanyID {
    $uri = "$baseUri/companies?name=$encodedCompanyName"
    try {
        $response = Invoke-RestMethod -Uri $uri -Method Get -Headers $headers
        if ($response.companies -and $response.companies.Count -gt 0) {
            return $response.companies[0].id
        } else {
            Write-Host "No company found with the name '$userCompanyName'. Exiting script."
            exit
        }
    } catch {
        Write-Error "Failed to retrieve the company ID: $($_.Exception.Message)"
        exit
    }
}

# Retrieve the company ID
$companyId = Get-CompanyID
if (-not $companyId) {
    Write-Host "Company ID could not be retrieved, cannot proceed with folder creation."
    exit
}

# Define folder details in an array
$folders = @(
    @{ Name = "BackupRecovery"; Description = "Procedures and schedules for data backup and disaster recovery plans." },
    @{ Name = "BusinessApplications"; Description = "Documentation related to business-specific software and applications, including user guides, configuration settings, and troubleshooting tips." },
    @{ Name = "InternalProcedures"; Description = "Standard operating procedures (SOPs), policies, and guidelines for internal processes and workflows." },
    @{ Name = "NetworkingDevices"; Description = "Documentation for routers, switches, firewalls, and other networking equipment, including configuration files and maintenance logs." },
    @{ Name = "OnboardingDocumentation"; Description = "For storing all onboarding reports, checklists, and related documents for new clients or employees." },
    @{ Name = "ProjectDocumentation"; Description = "Documentation related to ongoing and completed projects, including scope, timelines, and deliverables." },
    @{ Name = "SecurityPolicies"; Description = "Documents related to cybersecurity policies, incident response plans, and security best practices." },
    @{ Name = "SiteInformation"; Description = "Information about physical and virtual sites, including floor plans, network diagrams, and contact lists." },
    @{ Name = "TrainingMaterials"; Description = "Guides, tutorials, and training materials for end-users on various systems and applications." },
    @{ Name = "VendorInformation"; Description = "Contracts, contact details, and support information for third-party vendors and service providers." }
)

# Confirmation for folder creation
Write-Host "`nFolders to be created:"
$folders | ForEach-Object { Write-Host "# $($_.Name): $($_.Description)" }
$confirmation = Read-Host "Confirm folder creation with above details (Y/N) [Y]"
if ($confirmation -ne 'Y' -and $confirmation -ne '') {
    Write-Host "Folder creation cancelled by user."
    return
}

# Function to create a folder
function New-Folder {
    param (
        [string]$name,
        [string]$description,
        [string]$companyId,
        [string]$parentFolderId = $null
    )
    $folderDetails = @{
        "folder" = @{
            "company_id" = $companyId
            "description" = $description
            "name" = $name
            "parent_folder_id" = $parentFolderId
        }
    }
    $jsonBody = $folderDetails | ConvertTo-Json -Depth 5
    Write-Host "Sending request to create folder: '$name' with description: '$description'"

    try {
        $response = Invoke-RestMethod -Uri ($baseUri + "folders") -Method Post -Headers $headers -Body $jsonBody
        Write-Host "Folder '$name' created successfully with ID: $($response.folder.id)" -ForegroundColor Green
        return $response.folder.id
    } catch {
        Write-Error "Failed to create the folder '$name': $($_.Exception.Message)"
        return $null
    }
}

# Create each folder and track the folder IDs for subfolder creation
$folderIds = @{}
foreach ($folder in $folders) {
    $folderId = New-Folder -name $folder.Name -description $folder.Description -companyId $companyId
    $folderIds[$folder.Name] = $folderId
}

# Subfolder creation under "OnboardingDocumentation"
$onboardingFolderId = $folderIds["OnboardingDocumentation"]
if ($onboardingFolderId) {
    Write-Host "Creating subfolder 'PreOnboarding' under 'OnboardingDocumentation' with ID: $onboardingFolderId"
    $subFolderId = New-Folder -name "PreOnboarding" -description "Used for reports etc that were collected prior to us making any modifications" -companyId $companyId -parentFolderId $onboardingFolderId
    if ($subFolderId) {
        Write-Host "Subfolder 'PreOnboarding' created successfully." -ForegroundColor Green
    } else {
        Write-Host "Failed to create subfolder 'PreOnboarding'." -ForegroundColor Red
    }
} else {
    Write-Host "Failed to retrieve ID for 'OnboardingDocumentation', subfolder creation aborted." -ForegroundColor Red
}

Write-Host "Folders and subfolders have been created as requested."
