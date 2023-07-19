
<#

.COPYRIGHT
Copyright (c) Microsoft Corporation. All rights reserved. Licensed under the MIT license.
See LICENSE in the project root for license information.

#>

####################################################

## 20230322 - Replace Get-AuthToken function using MSAL. The original script is using ADAL
# Requirement: 
#   1. Install Microsoft.Identity.Client module 
#   2. Install Microsoft.IdentityModel.Abstractions module. This module requires Nuget is registered as PSRepository
#           Register-PSRepository  -Name Nuget -SourceLocation "http://www.nuget.org/api/v2"

Install-Module -Name Microsoft.Identity.Client
Import-module -name Microsoft.Identity.Client

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
        # Write-Host "Get Microsoft.Graph.Authentication - Start"
        $AadModule = Get-Module -Name "Microsoft.Graph.Authentication" -ListAvailable -ErrorAction Stop
        # Write-Host "Get Microsoft.Graph.Authentication - Start 2"

        $MICModule = Get-Module -Name "Microsoft.Identity.Client" -ListAvailable -ErrorAction Stop
        # Write-Host "Get Microsoft.Graph.Authentication - Start 3"

        $MIAModule = Get-Module -Name "Microsoft.IdentityModel.Abstractions" -ListAvailable -ErrorAction Stop
        # Write-Host "Get Microsoft.Graph.Authentication - End"

    

       $latestVersion = ($AadModule | Sort-Object Version -Descending)[0].Version
       Import-Module -Name  $($AadModule.Name) -RequiredVersion $latestVersion
       #   import-module -Name "Microsoft.Graph.Authentication"
#       $latestVersion = ($MICModule | Sort-Object Version -Descending)[0].Version

#       import-module -Name ($MICModule.Name) -RequiredVersion $latestVersion

    }
    catch {
        Write-Host "Microsoft.Graph.Authentication PowerShell module not found." -f Red
        Write-Host "Install by running 'Install-Module Microsoft.Graph.Authentication' from an elevated PowerShell prompt" -f Yellow
        Write-Host "Script can't continue..." -f Red
        exit
    }
    
    $clientId = "d1ddf0e4-d672-4dae-b554-9d5bdfd93547"
    [String[]] $scopes = @("DeviceManagementServiceConfig.ReadWrite.All","DeviceManagementConfiguration.ReadWrite.All","DeviceManagementApps.ReadWrite.All")
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
    Write-Host 
    write-host $uri
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

####################################################

Function Get-SettingsCatalogPolicy(){

    <#
    .SYNOPSIS
    This function is used to get Settings Catalog policies from the Graph API REST interface
    .DESCRIPTION
    The function connects to the Graph API Interface and gets any Settings Catalog policies
    .EXAMPLE
    Get-SettingsCatalogPolicy
    Returns any Settings Catalog policies configured in Intune
    Get-SettingsCatalogPolicy -Platform windows10
    Returns any Windows 10 Settings Catalog policies configured in Intune
    Get-SettingsCatalogPolicy -Platform macOS
    Returns any MacOS Settings Catalog policies configured in Intune
    .NOTES
    NAME: Get-SettingsCatalogPolicy
    #>
    
    [cmdletbinding()]
    
    param
    (
     [parameter(Mandatory=$false)]
     [ValidateSet("windows10","macOS")]
     [ValidateNotNullOrEmpty()]
     [string]$Platform
    )
    
    $graphApiVersion = "beta"
    
        if($Platform){
            
            $Resource = "deviceManagement/configurationPolicies?`$filter=platforms has '$Platform' and technologies has 'mdm'"
    
        }
    
        else {
    
            $Resource = "deviceManagement/configurationPolicies?`$filter=technologies has 'mdm'"
    
        }
    
        try {
    
            $uri = "https://graph.microsoft.com/$graphApiVersion/$($Resource)"
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
    
    Function Get-SettingsCatalogPolicySettings(){
    
    <#
    .SYNOPSIS
    This function is used to get Settings Catalog policy Settings from the Graph API REST interface
    .DESCRIPTION
    The function connects to the Graph API Interface and gets any Settings Catalog policy Settings
    .EXAMPLE
    Get-SettingsCatalogPolicySettings -policyid policyid
    Returns any Settings Catalog policy Settings configured in Intune
    .NOTES
    NAME: Get-SettingsCatalogPolicySettings
    #>
    
    [cmdletbinding()]
    
    param
    (
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        $policyid
    )
    
    $graphApiVersion = "beta"
    $Resource = "deviceManagement/configurationPolicies('$policyid')/settings?`$expand=settingDefinitions"
    
        try {
    
            $uri = "https://graph.microsoft.com/$graphApiVersion/$($Resource)"
    
            $Response = (Invoke-RestMethod -Uri $uri -Headers $authToken -Method Get)
    
            $AllResponses = $Response.value
         
            $ResponseNextLink = $Response."@odata.nextLink"
    
            while ($ResponseNextLink -ne $null){
    
                $Response = (Invoke-RestMethod -Uri $ResponseNextLink -Headers $authToken -Method Get)
                $ResponseNextLink = $Response."@odata.nextLink"
                $AllResponses += $Response.value
    
            }
    
            return $AllResponses
    
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
    
    Function Get-GroupPolicyConfigurations()
    {
        
    <#
    .SYNOPSIS
    This function is used to get device configuration policies from the Graph API REST interface
    .DESCRIPTION
    The function connects to the Graph API Interface and gets any device configuration policies
    .EXAMPLE
    Get-DeviceConfigurationPolicy
    Returns any device configuration policies configured in Intune
    .NOTES
    NAME: Get-GroupPolicyConfigurations
    #>
        
        [cmdletbinding()]
        
        $graphApiVersion = "Beta"
        $DCP_resource = "deviceManagement/groupPolicyConfigurations"
        
        try
        {
            
            $uri = "https://graph.microsoft.com/$graphApiVersion/$($DCP_resource)"
            (Invoke-RestMethod -Uri $uri -Headers $authToken -Method Get).Value
            
        }
        
        catch
        {
            
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
    Function Get-GroupPolicyConfigurationsDefinitionValues()
    {
        
        <#
        .SYNOPSIS
        This function is used to get device configuration policies from the Graph API REST interface
        .DESCRIPTION
        The function connects to the Graph API Interface and gets any device configuration policies
        .EXAMPLE
        Get-DeviceConfigurationPolicy
        Returns any device configuration policies configured in Intune
        .NOTES
        NAME: Get-GroupPolicyConfigurations
        #>
        
        [cmdletbinding()]
        Param (
            
            [Parameter(Mandatory = $true)]
            [string]$GroupPolicyConfigurationID
            
        )
        
        $graphApiVersion = "Beta"
        #$DCP_resource = "deviceManagement/groupPolicyConfigurations/$GroupPolicyConfigurationID/definitionValues?`$filter=enabled eq true"
        $DCP_resource = "deviceManagement/groupPolicyConfigurations/$GroupPolicyConfigurationID/definitionValues"
        
        
        try
        {
            
            $uri = "https://graph.microsoft.com/$graphApiVersion/$($DCP_resource)"
            (Invoke-RestMethod -Uri $uri -Headers $authToken -Method Get).Value
            
        }
        
        catch
        {
            
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
    Function Get-GroupPolicyConfigurationsDefinitionValuesPresentationValues()
    {
        
        <#
        .SYNOPSIS
        This function is used to get device configuration policies from the Graph API REST interface
        .DESCRIPTION
        The function connects to the Graph API Interface and gets any device configuration policies
        .EXAMPLE
        Get-DeviceConfigurationPolicy
        Returns any device configuration policies configured in Intune
        .NOTES
        NAME: Get-GroupPolicyConfigurations
        #>
        
        [cmdletbinding()]
        Param (
            
            [Parameter(Mandatory = $true)]
            [string]$GroupPolicyConfigurationID,
            [string]$GroupPolicyConfigurationsDefinitionValueID
            
        )
        $graphApiVersion = "Beta"
        
        $DCP_resource = "deviceManagement/groupPolicyConfigurations/$GroupPolicyConfigurationID/definitionValues/$GroupPolicyConfigurationsDefinitionValueID/presentationValues"
        
        try
        {
            
            $uri = "https://graph.microsoft.com/$graphApiVersion/$($DCP_resource)"
            (Invoke-RestMethod -Uri $uri -Headers $authToken -Method Get).Value
            
        }
        
        catch
        {
            
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
    
    Function Get-GroupPolicyConfigurationsDefinitionValuesdefinition ()
    {
       <#
        .SYNOPSIS
        This function is used to get device configuration policies from the Graph API REST interface
        .DESCRIPTION
        The function connects to the Graph API Interface and gets any device configuration policies
        .EXAMPLE
        Get-DeviceConfigurationPolicy
        Returns any device configuration policies configured in Intune
        .NOTES
        NAME: Get-GroupPolicyConfigurations
        #>
        
        [cmdletbinding()]
        Param (
            
            [Parameter(Mandatory = $true)]
            [string]$GroupPolicyConfigurationID,
            [Parameter(Mandatory = $true)]
            [string]$GroupPolicyConfigurationsDefinitionValueID
            
        )
        $graphApiVersion = "Beta"
        $DCP_resource = "deviceManagement/groupPolicyConfigurations/$GroupPolicyConfigurationID/definitionValues/$GroupPolicyConfigurationsDefinitionValueID/definition"
        
        try
        {
            
            $uri = "https://graph.microsoft.com/$graphApiVersion/$($DCP_resource)"
            
            $responseBody = Invoke-RestMethod -Uri $uri -Headers $authToken -Method Get
            
            
        }
        
        catch
        {
            
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
        $responseBody
    }
    
    
    Function Get-GroupPolicyDefinitionsPresentations ()
    {
       <#
        .SYNOPSIS
        This function is used to get device configuration policies from the Graph API REST interface
        .DESCRIPTION
        The function connects to the Graph API Interface and gets any device configuration policies
        .EXAMPLE
        Get-DeviceConfigurationPolicy
        Returns any device configuration policies configured in Intune
        .NOTES
        NAME: Get-GroupPolicyConfigurations
        #>
        
        [cmdletbinding()]
        Param (
            
            
            [Parameter(Mandatory = $true)]
            [string]$groupPolicyDefinitionsID,
            [Parameter(Mandatory = $true)]
            [string]$GroupPolicyConfigurationsDefinitionValueID
            
        )
        $graphApiVersion = "Beta"
        $DCP_resource = "deviceManagement/groupPolicyConfigurations/$groupPolicyDefinitionsID/definitionValues/$GroupPolicyConfigurationsDefinitionValueID/presentationValues?`$expand=presentation"
        try
        {
            
            $uri = "https://graph.microsoft.com/$graphApiVersion/$($DCP_resource)"
            
            (Invoke-RestMethod -Uri $uri -Headers $authToken -Method Get).Value.presentation
            
            
        }
        
        catch
        {
            
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
    
    Function Get-EndpointSecurityTemplate(){

        <#
        .SYNOPSIS
        This function is used to get all Endpoint Security templates using the Graph API REST interface
        .DESCRIPTION
        The function connects to the Graph API Interface and gets all Endpoint Security templates
        .EXAMPLE
        Get-EndpointSecurityTemplate 
        Gets all Endpoint Security Templates in Endpoint Manager
        .NOTES
        NAME: Get-EndpointSecurityTemplate
        #>
        
        
        $graphApiVersion = "Beta"
        $ESP_resource = "deviceManagement/templates?`$filter=(isof(%27microsoft.graph.securityBaselineTemplate%27))"
        
            try {
        
                $uri = "https://graph.microsoft.com/$graphApiVersion/$($ESP_resource)"
                (Invoke-RestMethod -Method Get -Uri $uri -Headers $authToken).value
        
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
        
        Function Get-EndpointSecurityPolicy(){
        
        <#
        .SYNOPSIS
        This function is used to get all Endpoint Security policies using the Graph API REST interface
        .DESCRIPTION
        The function connects to the Graph API Interface and gets all Endpoint Security templates
        .EXAMPLE
        Get-EndpointSecurityPolicy
        Gets all Endpoint Security Policies in Endpoint Manager
        .NOTES
        NAME: Get-EndpointSecurityPolicy
        #>
        
        
        $graphApiVersion = "Beta"
        $ESP_resource = "deviceManagement/intents"
        
            try {
        
                $uri = "https://graph.microsoft.com/$graphApiVersion/$($ESP_resource)"
                (Invoke-RestMethod -Method Get -Uri $uri -Headers $authToken).value
        
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
        
        Function Get-EndpointSecurityTemplateCategory(){
        
        <#
        .SYNOPSIS
        This function is used to get all Endpoint Security categories from a specific template using the Graph API REST interface
        .DESCRIPTION
        The function connects to the Graph API Interface and gets all template categories
        .EXAMPLE
        Get-EndpointSecurityTemplateCategory -TemplateId $templateId
        Gets an Endpoint Security Categories from a specific template in Endpoint Manager
        .NOTES
        NAME: Get-EndpointSecurityTemplateCategory
        #>
        
        [cmdletbinding()]
        
        param
        (
            [Parameter(Mandatory=$true)]
            [ValidateNotNullOrEmpty()]
            $TemplateId
        )
        
        $graphApiVersion = "Beta"
        $ESP_resource = "deviceManagement/templates/$TemplateId/categories"
        
            try {
        
                $uri = "https://graph.microsoft.com/$graphApiVersion/$($ESP_resource)"
                (Invoke-RestMethod -Method Get -Uri $uri -Headers $authToken).value
        
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
        
        Function Get-EndpointSecurityCategorySetting(){
        
        <#
        .SYNOPSIS
        This function is used to get an Endpoint Security category setting from a specific policy using the Graph API REST interface
        .DESCRIPTION
        The function connects to the Graph API Interface and gets a policy category setting
        .EXAMPLE
        Get-EndpointSecurityCategorySetting -PolicyId $policyId -categoryId $categoryId
        Gets an Endpoint Security Categories from a specific template in Endpoint Manager
        .NOTES
        NAME: Get-EndpointSecurityCategory
        #>
        
        [cmdletbinding()]
        
        param
        (
            [Parameter(Mandatory=$true)]
            [ValidateNotNullOrEmpty()]
            $PolicyId,
            [Parameter(Mandatory=$true)]
            [ValidateNotNullOrEmpty()]
            $categoryId
        )
        
        $graphApiVersion = "Beta"
        $ESP_resource = "deviceManagement/intents/$policyId/categories/$categoryId/settings?`$expand=Microsoft.Graph.DeviceManagementComplexSettingInstance/Value"
        
            try {
        
                $uri = "https://graph.microsoft.com/$graphApiVersion/$($ESP_resource)"
                (Invoke-RestMethod -Method Get -Uri $uri -Headers $authToken).value
        
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
  
        Function Get-DeviceCompliancePolicy(){

            <#
            .SYNOPSIS
            This function is used to get device compliance policies from the Graph API REST interface
            .DESCRIPTION
            The function connects to the Graph API Interface and gets any device compliance policies
            .EXAMPLE
            Get-DeviceCompliancePolicy
            Returns any device compliance policies configured in Intune
            .EXAMPLE
            Get-DeviceCompliancePolicy -Android
            Returns any device compliance policies for Android configured in Intune
            .EXAMPLE
            Get-DeviceCompliancePolicy -iOS
            Returns any device compliance policies for iOS configured in Intune
            .NOTES
            NAME: Get-DeviceCompliancePolicy
            #>
            
            [cmdletbinding()]
            
            param
            (
                [switch]$Android,
                [switch]$iOS,
                [switch]$Win10
            )
            
            $graphApiVersion = "Beta"
            $Resource = "deviceManagement/deviceCompliancePolicies"
                
                try {
            
                    $Count_Params = 0
            
                    if($Android.IsPresent){ $Count_Params++ }
                    if($iOS.IsPresent){ $Count_Params++ }
                    if($Win10.IsPresent){ $Count_Params++ }
            
                    if($Count_Params -gt 1){
                    
                    write-host "Multiple parameters set, specify a single parameter -Android -iOS or -Win10 against the function" -f Red
                    
                    }
                    
                    elseif($Android){
                    
                    $uri = "https://graph.microsoft.com/$graphApiVersion/$($Resource)"
                    (Invoke-RestMethod -Uri $uri -Headers $authToken -Method Get).Value | Where-Object { ($_.'@odata.type').contains("android") }
                    
                    }
                    
                    elseif($iOS){
                    
                    $uri = "https://graph.microsoft.com/$graphApiVersion/$($Resource)"
                    (Invoke-RestMethod -Uri $uri -Headers $authToken -Method Get).Value | Where-Object { ($_.'@odata.type').contains("ios") }
                    
                    }
            
                    elseif($Win10){
                    
                    $uri = "https://graph.microsoft.com/$graphApiVersion/$($Resource)"
                    (Invoke-RestMethod -Uri $uri -Headers $authToken -Method Get).Value | Where-Object { ($_.'@odata.type').contains("windows10CompliancePolicy") }
                    
                    }
                    
                    else {
            
                    $uri = "https://graph.microsoft.com/$graphApiVersion/$($Resource)"
                    (Invoke-RestMethod -Uri $uri -Headers $authToken -Method Get).Value
            
                    }
            
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

            Function Get-IntuneApplication(){

                <#
                .SYNOPSIS
                This function is used to get applications from the Graph API REST interface
                .DESCRIPTION
                The function connects to the Graph API Interface and gets any applications added
                .EXAMPLE
                Get-IntuneApplication
                Returns any applications configured in Intune
                .NOTES
                NAME: Get-IntuneApplication
                #>
                
                [cmdletbinding()]
                
                param
                (
                    $Name,
                    $AppId
                )
                
                $graphApiVersion = "Beta"
                $Resource = "deviceAppManagement/mobileApps"
                
                    try {
                
                        if($Name){
                
                        $uri = "https://graph.microsoft.com/$graphApiVersion/$($Resource)"
                        (Invoke-RestMethod -Uri $uri -Headers $authToken -Method Get).Value | Where-Object { ($_.'displayName').contains("$Name") -and (!($_.'@odata.type').Contains("managed")) -and (!($_.'@odata.type').Contains("#microsoft.graph.iosVppApp")) }
                
                        }
                
                        elseif($AppId){
                
                        $uri = "https://graph.microsoft.com/$graphApiVersion/$($Resource)/$AppId"
                        (Invoke-RestMethod -Uri $uri -Headers $authToken -Method Get)
                
                        }
                
                        else {
                
                        $uri = "https://graph.microsoft.com/$graphApiVersion/$($Resource)"
                        (Invoke-RestMethod -Uri $uri -Headers $authToken -Method Get).Value | ? { (!($_.'@odata.type').Contains("managed")) -and (!($_.'@odata.type').Contains("#microsoft.graph.iosVppApp")) -and (!($_.'@odata.type').Contains("#microsoft.graph.windowsAppX")) -and (!($_.'@odata.type').Contains("#microsoft.graph.androidForWorkApp")) -and (!($_.'@odata.type').Contains("#microsoft.graph.windowsMobileMSI")) -and (!($_.'@odata.type').Contains("#microsoft.graph.androidLobApp")) -and (!($_.'@odata.type').Contains("#microsoft.graph.iosLobApp")) -and (!($_.'@odata.type').Contains("#microsoft.graph.microsoftStoreForBusinessApp")) }
                
                        }
                
                    }
                
                    catch {
                
                    $ex = $_.Exception
                    Write-Host "Request to $Uri failed with HTTP Status $([int]$ex.Response.StatusCode) $($ex.Response.StatusDescription)" -f Red
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

                
####################################################

Function Get-ManagedAppPolicy(){

    <#
    .SYNOPSIS
    This function is used to get managed app policies from the Graph API REST interface
    .DESCRIPTION
    The function connects to the Graph API Interface and gets any managed app policies
    .EXAMPLE
    Get-ManagedAppPolicy
    Returns any managed app policies configured in Intune
    .NOTES
    NAME: Get-ManagedAppPolicy
    #>
    
    [cmdletbinding()]
    
    param
    (
        $Name
    )
    
    $graphApiVersion = "Beta"
    $Resource = "deviceAppManagement/managedAppPolicies"
    
        try {
        
            if($Name){
        
            $uri = "https://graph.microsoft.com/$graphApiVersion/$($Resource)"
            (Invoke-RestMethod -Uri $uri -Headers $authToken -Method Get).Value | Where-Object { ($_.'displayName').contains("$Name") }
        
            }
        
            else {
        
            $uri = "https://graph.microsoft.com/$graphApiVersion/$($Resource)"
            (Invoke-RestMethod -Uri $uri -Headers $authToken -Method Get).Value | Where-Object { ($_.'@odata.type').contains("ManagedAppProtection") -or ($_.'@odata.type').contains("InformationProtectionPolicy") }
        
            }
        
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
    
    Function Get-ManagedAppProtection(){
    
    <#
    .SYNOPSIS
    This function is used to get managed app protection configuration from the Graph API REST interface
    .DESCRIPTION
    The function connects to the Graph API Interface and gets any managed app protection policy
    .EXAMPLE
    Get-ManagedAppProtection -id $id -OS "Android"
    Returns a managed app protection policy for Android configured in Intune
    Get-ManagedAppProtection -id $id -OS "iOS"
    Returns a managed app protection policy for iOS configured in Intune
    Get-ManagedAppProtection -id $id -OS "WIP_WE"
    Returns a managed app protection policy for Windows 10 without enrollment configured in Intune
    .NOTES
    NAME: Get-ManagedAppProtection
    #>
    
    [cmdletbinding()]
    
    param
    (
        [Parameter(Mandatory=$true)]
        $id,
        [Parameter(Mandatory=$true)]
        [ValidateSet("Android","iOS","WIP_WE","WIP_MDM")]
        $OS    
    )
    
    $graphApiVersion = "Beta"
    
        try {
        
            if($id -eq "" -or $id -eq $null){
        
            write-host "No Managed App Policy id specified, please provide a policy id..." -f Red
            break
        
            }
        
            else {
        
                if($OS -eq "" -or $OS -eq $null){
        
                write-host "No OS parameter specified, please provide an OS. Supported value are Android,iOS,WIP_WE,WIP_MDM..." -f Red
                Write-Host
                break
        
                }
        
                elseif($OS -eq "Android"){
        
                $Resource = "deviceAppManagement/androidManagedAppProtections('$id')/?`$expand=apps"
        
                $uri = "https://graph.microsoft.com/$graphApiVersion/$($Resource)"
                Invoke-RestMethod -Uri $uri -Headers $authToken -Method Get
        
                }
        
                elseif($OS -eq "iOS"){
        
                $Resource = "deviceAppManagement/iosManagedAppProtections('$id')/?`$expand=apps"
        
                $uri = "https://graph.microsoft.com/$graphApiVersion/$($Resource)"
                Invoke-RestMethod -Uri $uri -Headers $authToken -Method Get
        
                }
    
                elseif($OS -eq "WIP_WE"){
        
                $Resource = "deviceAppManagement/windowsInformationProtectionPolicies('$id')?`$expand=protectedAppLockerFiles,exemptAppLockerFiles,assignments"
        
                $uri = "https://graph.microsoft.com/$graphApiVersion/$($Resource)"
                Invoke-RestMethod -Uri $uri -Headers $authToken -Method Get
        
                }
    
                elseif($OS -eq "WIP_MDM"){
        
                $Resource = "deviceAppManagement/mdmWindowsInformationProtectionPolicies('$id')?`$expand=protectedAppLockerFiles,exemptAppLockerFiles,assignments"
        
                $uri = "https://graph.microsoft.com/$graphApiVersion/$($Resource)"
                Invoke-RestMethod -Uri $uri -Headers $authToken -Method Get
    
                }
        
            }
        
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

Function Export-APPJSONData(){

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
    $Type,
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
    
            $JSON1 = ConvertTo-Json $JSON
    
            $JSON_Convert = $JSON1 | ConvertFrom-Json
    
            $displayName = $JSON_Convert.displayName
    
            # Updating display name to follow file naming conventions - https://msdn.microsoft.com/en-us/library/windows/desktop/aa365247%28v=vs.85%29.aspx
            $DisplayName = $DisplayName -replace '\<|\>|:|"|/|\\|\||\?|\*', "_"
    
            $Properties = ($JSON_Convert | Get-Member | ? { $_.MemberType -eq "NoteProperty" }).Name
    
                if($Type){
    
                #    $FileName_CSV = "$DisplayName" + "_" + $Type + "_" + $(get-date -f dd-MM-yyyy-H-mm-ss) + ".csv"
                    $FileName_JSON = "$DisplayName" + "_" + $Type  + ".json"
    
                }
    
                else {
    
                #    $FileName_CSV = "$DisplayName" + "_" + $(get-date -f dd-MM-yyyy-H-mm-ss) + ".csv"
                    $FileName_JSON = "$DisplayName" +  ".json"
    
                }
    
                $Object = New-Object System.Object
    
                    foreach($Property in $Properties){
    
                    $Object | Add-Member -MemberType NoteProperty -Name $Property -Value $JSON_Convert.$Property
    
                    }
    
                write-host "Export Path:" "$ExportPath"
    
            #    $Object | Export-Csv -LiteralPath "$ExportPath\$FileName_CSV" -Delimiter "," -NoTypeInformation -Append
                $JSON1 | Set-Content -LiteralPath "$ExportPath\$FileName_JSON"
            #    write-host "CSV created in $ExportPath\$FileName_CSV..." -f cyan
                write-host "JSON created in $ExportPath\$FileName_JSON..." -f cyan
                
            }
    
        }
    
        catch {
    
        $_.Exception
    
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
$ExportPath,
$depth

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

            $JSON1 = ConvertTo-Json $JSON -Depth $depth

            $JSON_Convert = $JSON1 | ConvertFrom-Json

            $displayName = $JSON_Convert.displayName
            if (!$displayName)
            {
                # In Setting Catalog, it is Name property 
                $displayName = $JSON_Convert.Name
            }

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

if ($PSVersionTable.PSVersion.Major -gt 5) {
    Write-Host "This script requires Windows PowerShell version 5!" -ForegroundColor Red
    exit 1
}


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
Write-Host "Get-AuthToken"
}

#endregion Authentication


####################################################

# $ExportPath = Read-Host -Prompt "Please specify a path to export the policy data to e.g. C:\IntuneOutput"

# Specify ExportPath folder. 
    $ExportPathRoot = "C:\IntuneOutput"

    # If the directory path doesn't exist prompt user to create the directory
    $ExportPathRoot = $ExportPathRoot.replace('"','')

    if(!(Test-Path "$ExportPathRoot")){

    Write-Host
    Write-Host "Path '$ExportPathRoot' doesn't exist. Create this directory." -ForegroundColor Yellow
    new-item -ItemType Directory -Path "$ExportPathRoot" | Out-Null
<#
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
#>
    }

####################################################


#Region Device Configuration
Write-Host


# Export Devcie Configuration
$ExportPath = $ExportPathRoot + "\" + "DeviceConfiguration"

if(!(Test-Path "$ExportPath")){

    Write-Host
    Write-Host "Path '$ExportPath' doesn't exist. Create this directory." -ForegroundColor Yellow
    new-item -ItemType Directory -Path "$ExportPath" | Out-Null
    }

Write-Host "Get-DeviceConfigurationPolicy"
$DCPs = Get-DeviceConfigurationPolicy | Where-Object { ($_.'@odata.type' -ne "#microsoft.graph.iosUpdateConfiguration") -and ($_.'@odata.type' -ne "#microsoft.graph.windowsUpdateForBusinessConfiguration") }

foreach($DCP in $DCPs){


write-host "Device Configuration Policy:"$DCP.displayName -f Yellow
Export-JSONData -JSON $DCP -ExportPath "$ExportPath" -depth 5
Write-Host

}

#EndRegion Device Configuration


#Region Setting Catalog
Write-Host

$ExportPath = $ExportPathRoot + "\" + "DeviceConfiguration"

if(!(Test-Path "$ExportPath")){

    Write-Host
    Write-Host "Path '$ExportPath' doesn't exist. Create this directory." -ForegroundColor Yellow
    new-item -ItemType Directory -Path "$ExportPath" | Out-Null
    }


$Policies = Get-SettingsCatalogPolicy

if($Policies){

    foreach($policy in $Policies){

        Write-Host $policy.name -ForegroundColor Yellow

        $AllSettingsInstances = @()

        $policyid = $policy.id
        $Policy_Technologies = $policy.technologies
        $Policy_Platforms = $Policy.platforms
        $Policy_Name = $Policy.name
        $Policy_Description = $policy.description

        $PolicyBody = New-Object -TypeName PSObject

        Add-Member -InputObject $PolicyBody -MemberType 'NoteProperty' -Name 'name' -Value "$Policy_Name"
        Add-Member -InputObject $PolicyBody -MemberType 'NoteProperty' -Name 'description' -Value "$Policy_Description"
        Add-Member -InputObject $PolicyBody -MemberType 'NoteProperty' -Name 'platforms' -Value "$Policy_Platforms"
        Add-Member -InputObject $PolicyBody -MemberType 'NoteProperty' -Name 'technologies' -Value "$Policy_Technologies"

        # Checking if policy has a templateId associated
        if($policy.templateReference.templateId){

            Write-Host "Found template reference" -f Cyan
            $templateId = $policy.templateReference.templateId

            $PolicyTemplateReference = New-Object -TypeName PSObject

            Add-Member -InputObject $PolicyTemplateReference -MemberType 'NoteProperty' -Name 'templateId' -Value $templateId

            Add-Member -InputObject $PolicyBody -MemberType 'NoteProperty' -Name 'templateReference' -Value $PolicyTemplateReference

        }

        $SettingInstances = Get-SettingsCatalogPolicySettings -policyid $policyid

        $Instances = $SettingInstances.settingInstance

        foreach($object in $Instances){

            $Instance = New-Object -TypeName PSObject

            Add-Member -InputObject $Instance -MemberType 'NoteProperty' -Name 'settingInstance' -Value $object
            $AllSettingsInstances += $Instance

        }

        Add-Member -InputObject $PolicyBody -MemberType 'NoteProperty' -Name 'settings' -Value @($AllSettingsInstances)

        Export-JSONData -JSON $PolicyBody -ExportPath "$ExportPath" -depth 20
        Write-Host

    }

}

else {

    Write-Host "No Settings Catalog policies found..." -ForegroundColor Red
    Write-Host

}

#EndRegion Setting Catalog


#Region Administrative Template
# 
Write-Host

$DCPs = Get-GroupPolicyConfigurations
$ExportPath = $ExportPathRoot + "\" + "DeviceConfiguration"

foreach ($DCP in $DCPs)
{
	$FolderName = $($DCP.displayName) -replace '\<|\>|:|"|/|\\|\||\?|\*', "_"
	New-Item "$ExportPath\$($FolderName)" -ItemType Directory -Force
	
	$GroupPolicyConfigurationsDefinitionValues = Get-GroupPolicyConfigurationsDefinitionValues -GroupPolicyConfigurationID $DCP.id
	foreach ($GroupPolicyConfigurationsDefinitionValue in $GroupPolicyConfigurationsDefinitionValues)
	{
		$GroupPolicyConfigurationsDefinitionValue
		$DefinitionValuedefinition = Get-GroupPolicyConfigurationsDefinitionValuesdefinition -GroupPolicyConfigurationID $DCP.id -GroupPolicyConfigurationsDefinitionValueID $GroupPolicyConfigurationsDefinitionValue.id
		$DefinitionValuedefinitionID = $DefinitionValuedefinition.id
		$DefinitionValuedefinitionDisplayName = $DefinitionValuedefinition.displayName
		$GroupPolicyDefinitionsPresentations = Get-GroupPolicyDefinitionsPresentations -groupPolicyDefinitionsID $DCP.id -GroupPolicyConfigurationsDefinitionValueID $GroupPolicyConfigurationsDefinitionValue.id
		$DefinitionValuePresentationValues = Get-GroupPolicyConfigurationsDefinitionValuesPresentationValues -GroupPolicyConfigurationID $DCP.id -GroupPolicyConfigurationsDefinitionValueID $GroupPolicyConfigurationsDefinitionValue.id
		$OutDef = New-Object -TypeName PSCustomObject
        $OutDef | Add-Member -MemberType NoteProperty -Name "definition@odata.bind" -Value "https://graph.microsoft.com/beta/deviceManagement/groupPolicyDefinitions('$definitionValuedefinitionID')"
        $OutDef | Add-Member -MemberType NoteProperty -Name "enabled" -value $($GroupPolicyConfigurationsDefinitionValue.enabled.tostring().tolower())
        if ($DefinitionValuePresentationValues) {
            $i = 0
            $PresValues = @()
            foreach ($Pres in $DefinitionValuePresentationValues) {
                $P = $pres | Select-Object -Property * -ExcludeProperty id, createdDateTime, lastModifiedDateTime, version
                $GPDPID = $groupPolicyDefinitionsPresentations[$i].id
                $P | Add-Member -MemberType NoteProperty -Name "presentation@odata.bind" -Value "https://graph.microsoft.com/beta/deviceManagement/groupPolicyDefinitions('$definitionValuedefinitionID')/presentations('$GPDPID')"
                $PresValues += $P
                $i++
            }
            $OutDef | Add-Member -MemberType NoteProperty -Name "presentationValues" -Value $PresValues
        }
		$FileName = (Join-Path $DefinitionValuedefinition.categoryPath $($definitionValuedefinitionDisplayName)) -replace '\<|\>|:|"|/|\\|\||\?|\*', "_"
		$OutDefjson = ($OutDef | ConvertTo-Json -Depth 10).replace("\u0027","'")
		$OutDefjson | Out-File -FilePath "$ExportPath\$($folderName)\$fileName.json" -Encoding ascii
	}
}

Write-Host

#endregion Administrative Template

#Region Endpoint Security Templates
####################################################

# Get all Endpoint Security Templates
$Templates = Get-EndpointSecurityTemplate

####################################################

# Get all Endpoint Security Policies configured
$ESPolicies = Get-EndpointSecurityPolicy | Sort-Object displayName

####################################################

$ExportPath = $ExportPathRoot + "\" + "EndpointSecurity"

if(!(Test-Path "$ExportPath")){

    Write-Host
    Write-Host "Path '$ExportPath' doesn't exist. Create this directory." -ForegroundColor Yellow
    new-item -ItemType Directory -Path "$ExportPath" | Out-Null
    }


# Looping through all policies configured
foreach($policy in $ESPolicies){

    Write-Host "Endpoint Security Policy:"$policy.displayName -ForegroundColor Yellow
    $PolicyName = $policy.displayName
    $PolicyDescription = $policy.description
    $policyId = $policy.id
    $TemplateId = $policy.templateId
    $roleScopeTagIds = $policy.roleScopeTagIds

    $ES_Template = $Templates | ?  { $_.id -eq $policy.templateId }

    $TemplateDisplayName = $ES_Template.displayName
    $TemplateId = $ES_Template.id
    $versionInfo = $ES_Template.versionInfo

    if($TemplateDisplayName -eq "Endpoint detection and response"){

        Write-Host "Export of 'Endpoint detection and response' policy not included in sample script..." -ForegroundColor Magenta
        Write-Host

    }

    else {

        ####################################################

        # Creating object for JSON output
        $JSON = New-Object -TypeName PSObject

        Add-Member -InputObject $JSON -MemberType 'NoteProperty' -Name 'displayName' -Value "$PolicyName"
        Add-Member -InputObject $JSON -MemberType 'NoteProperty' -Name 'description' -Value "$PolicyDescription"
        Add-Member -InputObject $JSON -MemberType 'NoteProperty' -Name 'roleScopeTagIds' -Value $roleScopeTagIds
        Add-Member -InputObject $JSON -MemberType 'NoteProperty' -Name 'TemplateDisplayName' -Value "$TemplateDisplayName"
        Add-Member -InputObject $JSON -MemberType 'NoteProperty' -Name 'TemplateId' -Value "$TemplateId"
        Add-Member -InputObject $JSON -MemberType 'NoteProperty' -Name 'versionInfo' -Value "$versionInfo"

        ####################################################

        # Getting all categories in specified Endpoint Security Template
        $Categories = Get-EndpointSecurityTemplateCategory -TemplateId $TemplateId

        # Looping through all categories within the Template

        foreach($category in $Categories){

            $categoryId = $category.id

            $Settings += Get-EndpointSecurityCategorySetting -PolicyId $policyId -categoryId $categoryId
        
        }

        # Adding All settings to settingsDelta ready for JSON export
        Add-Member -InputObject $JSON -MemberType 'NoteProperty' -Name 'settingsDelta' -Value @($Settings)

        ####################################################

        Export-JSONData -JSON $JSON -ExportPath "$ExportPath" -depth 5

        Write-Host

        # Clearing up variables so previous data isn't exported in each policy
        Clear-Variable JSON
        Clear-Variable Settings

    }

}
#EndRegion Endpoint Security Templates

#Region Compliance Policy

$CPs = Get-DeviceCompliancePolicy

$ExportPath = $ExportPathRoot + "\" + "CompliancePolicy"

if(!(Test-Path "$ExportPath")){

    Write-Host
    Write-Host "Path '$ExportPath' doesn't exist. Create this directory." -ForegroundColor Yellow
    new-item -ItemType Directory -Path "$ExportPath" | Out-Null
    }

    foreach($CP in $CPs){

    write-host "Device Compliance Policy:"$CP.displayName -f Yellow
    Export-JSONData -JSON $CP -ExportPath "$ExportPath" -depth 5
    Write-Host

    }

#EndRegion Compliance Policy


#Region Applications

$MDMApps = Get-IntuneApplication

$ExportPath = $ExportPathRoot + "\" + "Applications"

if(!(Test-Path "$ExportPath")){

    Write-Host
    Write-Host "Path '$ExportPath' doesn't exist. Create this directory." -ForegroundColor Yellow
    new-item -ItemType Directory -Path "$ExportPath" | Out-Null
    }

if($MDMApps){

    foreach($App in $MDMApps){

        $Application = Get-IntuneApplication -AppId $App.id
        $Type = $Application.'@odata.type'.split(".")[2]


        write-host "MDM Application:"$Application.displayName -f Yellow
        Export-AppJSONData -JSON $Application -Type $Type -ExportPath "$ExportPath"
        Write-Host

    }

}

else {

    Write-Host "No MDM Applications added to the Intune Service..." -ForegroundColor Red
    Write-Host

}

#EndRegion Applications

#Region App Protection Policy

####################################################

write-host "Running query against Microsoft Graph for App Protection Policies" -f Yellow

$ManagedAppPolicies = Get-ManagedAppPolicy | ? { ($_.'@odata.type').contains("ManagedAppProtection") }
$ExportPath = $ExportPathRoot + "\" + "AppProtectionPolicy"

if(!(Test-Path "$ExportPath")){

    Write-Host
    Write-Host "Path '$ExportPath' doesn't exist. Create this directory." -ForegroundColor Yellow
    new-item -ItemType Directory -Path "$ExportPath" | Out-Null
    }


write-host

if($ManagedAppPolicies){

    foreach($ManagedAppPolicy in $ManagedAppPolicies){

    write-host "Managed App Policy:"$ManagedAppPolicy.displayName -f Cyan

        if($ManagedAppPolicy.'@odata.type' -eq "#microsoft.graph.androidManagedAppProtection"){

            $AppProtectionPolicy = Get-ManagedAppProtection -id $ManagedAppPolicy.id -OS "Android"

            $AppProtectionPolicy | Add-Member -MemberType NoteProperty -Name '@odata.type' -Value "#microsoft.graph.androidManagedAppProtection"

#            $AppProtectionPolicy

            Export-JSONData -JSON $AppProtectionPolicy -ExportPath "$ExportPath" -depth 5

        }

        elseif($ManagedAppPolicy.'@odata.type' -eq "#microsoft.graph.iosManagedAppProtection"){

            $AppProtectionPolicy = Get-ManagedAppProtection -id $ManagedAppPolicy.id -OS "iOS"

            $AppProtectionPolicy | Add-Member -MemberType NoteProperty -Name '@odata.type' -Value "#microsoft.graph.iosManagedAppProtection"

#            $AppProtectionPolicy

            Export-JSONData -JSON $AppProtectionPolicy -ExportPath "$ExportPath" -depth 5

        }

    Write-Host

    }

}

#EndRegion App Protection Policy
