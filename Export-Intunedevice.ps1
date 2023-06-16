#



Select-MgProfile -Name beta
Connect-MgGraph -Scopes "DeviceManagementConfiguration.Read.All","DeviceManagementManagedDevices.Read.All","DeviceManagementServiceConfig.Read.All","Device.Read.All","Directory.Read.All"

# Change the group name in your environment, note that the script works only for group with dynamic rule
$groupname = "Android Device Group"
$group = Get-MgGroup -Filter "Displayname eq '$groupname'"

# Get dynamic group member
$groupdynmember = Get-MgGroupTransitiveMember -GroupId $group.id

# Find group member with type equal to "microsoft.graph.device"  
$AADDeviceObj = $groupdynmember | where {$_.AdditionalProperties["@odata.type"] -eq '#microsoft.graph.device'}

# Get the AAD device object
$mgdevices = $AADDeviceObj | % {get-mgdevice -filter "id eq '$($_.id)'"}

# Get the Intune device object
# $mgdevices | % {Get-MgDeviceManagementManagedDevice -Filter "AzureADDeviceID eq '$($_.DeviceId)'"  } | export-csv -path c:\temp\mdmdevicefromAADGroup.csv -NoTypeInformation
foreach ($device in $mgdevices)
{
    if ($device.EnrollmentProfileName -ne $null)
    {
        # Get Intune device using AAD device DeviceID property
        $IntuneDevice = Get-MgDeviceManagementManagedDevice -Filter "AzureAdDeviceId eq '$($device.DeviceId)'" 

        # Add new column to Intune device object with EnrollmentProfileName value from AAD device object
        # Since EnrollmentProfileName property is already in Intune device object, using a new column name "EnrollmentProfileNamefromAAD"
        $IntuneDevice | Add-Member -MemberType NoteProperty -Name "EnrollmentProfileNamefromAAD" -Value $($device.EnrollmentProfileName)

        # Export to CSV file
        $IntuneDevice | export-csv -Path c:\temp\mdmdevicefromAADGroup.csv -NoTypeInformation -Append
    }
}

