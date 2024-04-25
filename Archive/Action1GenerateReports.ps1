<#
.SYNOPSIS
This script fetches endpoint details from the Action1 platform based on a company name entered by the user, which retrieves the corresponding organization ID from Hudu. It then opens specific reports in Microsoft Edge using the Action1 platform.

.DESCRIPTION
The script prompts the user for a Hudu API key, retrieves the corresponding organization ID from Hudu, and opens specific reports for that organization in Microsoft Edge using the Action1 platform.

.NOTES
Author: Wallace Cinnamon | CinnTech
Version: 1.1
Creation Date: 2024-04-23
#>

# Function to securely retrieve the API key
function Get-SecureApiKey {
    $apiKey = $env:HuduApiKey
    if (-not $apiKey) {
        $apiKey = Read-Host -Prompt 'Enter your Hudu API key'
        if (-not $apiKey) {
            Write-Host "Hudu API key not provided. Exiting script."
            exit
        }
    }
    return $apiKey
}

# Retrieve the Hudu API key securely
$apiKey = Get-SecureApiKey

# Prompt the user for the company name
$companyName = Read-Host -Prompt 'Enter the company name'

# Notify the user to make sure they are logged in to Action1 before proceeding
Write-Host "Please ensure that you are logged into Action1 and have the application open before proceeding."
$confirmAction1 = Read-Host "Have you logged into Action1 and opened the application? (Press Enter for Yes)"
if (-not [string]::IsNullOrWhiteSpace($confirmAction1) -and $confirmAction1.ToLower() -ne 'y') {
    Write-Host "Please log in to Action1 and reopen this script."
    exit
}

# Define the base Hudu API URL
$huduApiUrl = 'https://cinntech.huducloud.com/api/v1'

# Function to perform the API request
function Invoke-HuduApiRequest {
    param (
        [string]$Endpoint,
        [string]$ApiKey
    )

    try {
        $headers = @{
            'accept' = 'application/json'
            'x-api-key' = $ApiKey
        }

        $uri = "$huduApiUrl$Endpoint"
        $response = Invoke-RestMethod -Uri $uri -Method Get -Headers $headers
        return $response
    } catch {
        Write-Host "Error: $($_.Exception.Message)"
        return $null
    }
}

# Encode the company name to be URL-safe
$encodedCompanyName = [System.Net.WebUtility]::UrlEncode($companyName)

# Invoke the Hudu API to search for the company
$response = Invoke-HuduApiRequest -Endpoint "/companies?name=$encodedCompanyName" -ApiKey $apiKey -Headers $headers

if ($response -and $response.companies -and $response.companies.count -gt 0) {
    $idNumber = $response.companies[0].id_number

    if (-not [string]::IsNullOrWhiteSpace($idNumber)) {
        # Define base URL for Action1
        $action1BaseUrl = "https://app.action1.com/console/reports/"

        # Define the list of report endpoints, without the org parameter
        $reportEndpoints = @(
        "web_browsers_1635330143409/summary?details=yes&from=0&limit=100&live_only=no",
        "weekly_update_summary_1709783347933/summary?details=yes&from=0&limit=100&live_only=no",
        "update_statistic_1635253368200/simple?details=no&from=0&limit=100&live_only=no",
        "local_user_accounts_1635431448458/summary?details=yes&from=0&limit=100&live_only=no",
        "open_network_shares_1635444487820/summary?details=yes&from=0&limit=100&live_only=no",
        "antivirus_status_1647107026187/simple?details=no&from=0&limit=100&live_only=no",
        "os_information_1635436732671/summary?details=yes&from=0&limit=100&live_only=no",
        "os_install_dates_1635436810796/simple?details=no&from=0&limit=100&live_only=no",
        "boot_configurations_1635437017447/simple?details=no&from=0&limit=100&live_only=no",
        "local_time_1635437915405/simple?details=no&from=0&limit=100&live_only=no",
        "windows_services_list_1635435913907/summary?details=yes&from=0&limit=100&live_only=no",
        "low_disk_space_1637319696228/simple?details=no&from=0&limit=100&live_only=no",
        "bitlocker_key_1652709701072/simple?details=no&from=0&limit=100&live_only=no",
        "installed_software_1635264799139/summary?details=yes&from=0&limit=100&live_only=no",
        "hardware_summary_1635380496058/simple?details=no&from=0&limit=100&live_only=no"
        )

        # Create new URLs with the organization ID
        $urlsToOpen = foreach ($endpoint in $reportEndpoints) {
            $action1BaseUrl + $endpoint + "&org=$idNumber"
        }

        # Display URLs to user for confirmation
        Write-Host "The following URLs will be opened in Microsoft Edge:"
        foreach ($url in $urlsToOpen) {
            Write-Host $url
        }

		# Ask for user confirmation to open URLs
		$confirmOpen = Read-Host "Do you want to open these URLs now? (Press Enter for Yes)"
		if ([string]::IsNullOrEmpty($confirmOpen) -or $confirmOpen.ToLower() -eq 'y') {
			foreach ($url in $urlsToOpen) {
				try {
					Start-Process "msedge" -ArgumentList $url
				} catch {
					Write-Host "Failed to open URL in Edge: $url"
					Write-Host "Error: $($_.Exception.Message)"
				}
			}
		} else {
			Write-Host "Operation cancelled by user."
		}

    } else {
        Write-Host "The organization ID is missing. Please update Hudu with the Action1 organization number to resolve this issue."
    }
} else {
    Write-Host "No company found with the specified name or an error occurred."
}
