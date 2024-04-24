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

Test-AppLockerPolicy
