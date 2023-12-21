# Simple function that gets the groups the Intune device is a member of, needs Intune Device ID
function Get-IntuneDeviceGroupMemberships {
    param (
        $DeviceID
    )
    # This is the Intune Device ID, but we can't use it because we need the Object ID of the device, which we can't get because none of the Intune API's get the ID.
    # Get the device displayName from the Intune Device ID
    $deviceName = Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/beta/deviceManagement/managedDevices/$($deviceId)?`$select=deviceName" | Select-Object -ExpandProperty deviceName
    # Get the Intune ObjectID from the device displayName
    $azureADdeviceID = Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/v1.0/devices?`$filter=displayName eq '$($deviceName)'" | Select-Object -ExpandProperty Value | Select-Object -ExpandProperty Id
    # Requires ObjectID (this is the Azure AD ID)
    $request = Invoke-MgGraphRequest -URI "https://graph.microsoft.com/v1.0/devices/$azureADdeviceID/memberOf" | Select-Object -ExpandProperty Value | Select-Object id, displayName
    # The reutned request contains all the groups the device is a member of.
    return $request
}