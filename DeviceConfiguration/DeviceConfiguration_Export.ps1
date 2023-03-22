
<#

.COPYRIGHT
Copyright (c) Microsoft Corporation. All rights reserved. Licensed under the MIT license.
See LICENSE in the project root for license information.

#>

####################################################

## 20230322 - Replace Get-AuthToken function using MSAL. The original script is using ADAL
function Get-AuthToken {

    <#
    .SYNOPSIS
    This function is used to authenticate with the Graph API REST interface
    .DESCRIPTION
    The function authenticate with the Graph API Interface with the tenant name
    .EXAMPLE
    Get-AuthToken
    Authenticates you with the Graph API interface
    .NOTES
    NAME: Get-AuthToken
    #>
    
    [cmdletbinding()]
    
    param
    (
        [Parameter(Mandatory=$true)]
        $User
    )
    
    $userUpn = New-Object "System.Net.Mail.MailAddress" -ArgumentList $User
    
    $tenant = $userUpn.Host
    
    Write-Host "Checking for AzureAD module..."
    
    try {
        Write-Host "Get Microsoft.Graph.Authentication - Start"
        $AadModule = Get-Module -Name "Microsoft.Graph.Authentication" -ListAvailable -ErrorAction Stop
        import-module Microsoft.Graph.Authentication -RequiredVersion 1.23.0
        Write-Host "Get Microsoft.Graph.Authentication - End"
    }
    catch {
        Write-Host "Microsoft.Graph.Authentication PowerShell module not found." -f Red
        Write-Host "Install by running 'Install-Module Microsoft.Graph.Authentication' from an elevated PowerShell prompt" -f Yellow
        Write-Host "Script can't continue..." -f Red
        exit
    }
    
    $clientId = "d1ddf0e4-d672-4dae-b554-9d5bdfd93547"
    [String[]] $scopes = @("user.read","DeviceManagementServiceConfig.ReadWrite.All")
    $redirectUri = "urn:ietf:wg:oauth:2.0:oob"
    
    $authority = "https://login.microsoftonline.com/$Tenant"
    
        try {
      ##      $app = [Microsoft.Identity.Client.PublicClientApplication]::new($clientId, $authority)
            Write-Host "Building application context..."
            $app1 = [Microsoft.Identity.Client.PublicClientApplicationBuilder]::Create($clientId)
            Write-Host "Building application context...1"
            $app1.WithAuthority($authority)
            $app1.WithRedirectUri($redirectUri)
            $app = $app1.Build()


            $authResult = $app.AcquireTokenInteractive($scopes).ExecuteAsync().Result
    
            # If the accesstoken is valid then create the authentication header
    
            if($authResult.AccessToken){
    
            # Creating header for Authorization token
    
            $authHeader = @{
                'Content-Type'='application/json'
                'Authorization'="Bearer " + $authResult.AccessToken
                'ExpiresOn'=$authResult.ExpiresOn
                }
            
            $global:authToken = $authHeader
                
            return 0
    
            }
    
            else {
    
            Write-Host
            Write-Host "Authorization Access Token is null, please re-run authentication..." -ForegroundColor Red
            Write-Host
            break
    
            }
    
        }
    
        catch {
    
        write-host $_.Exception.Message -f Red
        write-host $_.Exception.ItemName -f Red
        write-host
        break
    
        }
    
    }
    
####################################################

Function Get-DeviceConfigurationPolicy(){

<#
.SYNOPSIS
This function is used to get device configuration policies from the Graph API REST interface
.DESCRIPTION
The function connects to the Graph API Interface and gets any device configuration policies
.EXAMPLE
Get-DeviceConfigurationPolicy
Returns any device configuration policies configured in Intune
.NOTES
NAME: Get-DeviceConfigurationPolicy
#>

[cmdletbinding()]

$graphApiVersion = "Beta"
$DCP_resource = "deviceManagement/deviceConfigurations"
    
    try {
    
    $uri = "https://graph.microsoft.com/$graphApiVersion/$($DCP_resource)"
    (Invoke-RestMethod -Uri $uri -Headers $authToken -Method Get).Value
    
    }
    
    catch {

    $ex = $_.Exception
    $errorResponse = $ex.Response.GetResponseStream()
    $reader = New-Object System.IO.StreamReader($errorResponse)
    $reader.BaseStream.Position = 0
    $reader.DiscardBufferedData()
    $responseBody = $reader.ReadToEnd();
    Write-Host "Response content:`n$responseBody" -f Red
    Write-Error "Request to $Uri failed with HTTP Status $($ex.Response.StatusCode) $($ex.Response.StatusDescription)"
    write-host
    break

    }

}

####################################################

Function Export-JSONData(){

<#
.SYNOPSIS
This function is used to export JSON data returned from Graph
.DESCRIPTION
This function is used to export JSON data returned from Graph
.EXAMPLE
Export-JSONData -JSON $JSON
Export the JSON inputted on the function
.NOTES
NAME: Export-JSONData
#>

param (

$JSON,
$ExportPath

)

    try {

        if($JSON -eq "" -or $JSON -eq $null){

            write-host "No JSON specified, please specify valid JSON..." -f Red

        }

        elseif(!$ExportPath){

            write-host "No export path parameter set, please provide a path to export the file" -f Red

        }

        elseif(!(Test-Path $ExportPath)){

            write-host "$ExportPath doesn't exist, can't export JSON Data" -f Red

        }

        else {

            $JSON1 = ConvertTo-Json $JSON -Depth 5

            $JSON_Convert = $JSON1 | ConvertFrom-Json

            $displayName = $JSON_Convert.displayName

            # Updating display name to follow file naming conventions - https://msdn.microsoft.com/en-us/library/windows/desktop/aa365247%28v=vs.85%29.aspx
            $DisplayName = $DisplayName -replace '\<|\>|:|"|/|\\|\||\?|\*', "_"

# 
#           $FileName_JSON = "$DisplayName" + "_" + $(get-date -f dd-MM-yyyy-H-mm-ss) + ".json"
            $FileName_JSON = "$DisplayName" + ".json"


            write-host "Export Path:" "$ExportPath"

            $JSON1 | Set-Content -LiteralPath "$ExportPath\$FileName_JSON"
            write-host "JSON created in $ExportPath\$FileName_JSON..." -f cyan
            
        }

    }

    catch {

    $_.Exception

    }

}

####################################################

#region Authentication

write-host

# Checking if authToken exists before running authentication
if($global:authToken){

    # Setting DateTime to Universal time to work in all timezones
    $DateTime = (Get-Date).ToUniversalTime()

    # If the authToken exists checking when it expires
    $TokenExpires = ($authToken.ExpiresOn.datetime - $DateTime).Minutes

        if($TokenExpires -le 0){

        write-host "Authentication Token expired" $TokenExpires "minutes ago" -ForegroundColor Yellow
        write-host

            # Defining User Principal Name if not present

            if($User -eq $null -or $User -eq ""){

            $User = Read-Host -Prompt "Please specify your user principal name for Azure Authentication"
            Write-Host

            }

        Get-AuthToken -User $User

        }
}

# Authentication doesn't exist, calling Get-AuthToken function

else {

    if($User -eq $null -or $User -eq ""){

    $User = Read-Host -Prompt "Please specify your user principal name for Azure Authentication"
    Write-Host

    }

# Getting the authorization token
Get-AuthToken -User $User

}

#endregion

####################################################

$ExportPath = Read-Host -Prompt "Please specify a path to export the policy data to e.g. C:\IntuneOutput"

    # If the directory path doesn't exist prompt user to create the directory
    $ExportPath = $ExportPath.replace('"','')

    if(!(Test-Path "$ExportPath")){

    Write-Host
    Write-Host "Path '$ExportPath' doesn't exist, do you want to create this directory? Y or N?" -ForegroundColor Yellow

    $Confirm = read-host

        if($Confirm -eq "y" -or $Confirm -eq "Y"){

        new-item -ItemType Directory -Path "$ExportPath" | Out-Null
        Write-Host

        }

        else {

        Write-Host "Creation of directory path was cancelled..." -ForegroundColor Red
        Write-Host
        break

        }

    }

####################################################

Write-Host

# Filtering out iOS and Windows Software Update Policies
$DCPs = Get-DeviceConfigurationPolicy | Where-Object { ($_.'@odata.type' -ne "#microsoft.graph.iosUpdateConfiguration") -and ($_.'@odata.type' -ne "#microsoft.graph.windowsUpdateForBusinessConfiguration") }
foreach($DCP in $DCPs){

write-host "Device Configuration Policy:"$DCP.displayName -f Yellow
Export-JSONData -JSON $DCP -ExportPath "$ExportPath"
Write-Host

}

Write-Host
