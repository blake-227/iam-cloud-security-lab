# Northstar Defense Systems
# Automated Joiner Provisioning
# Employee: James Wilson
# Lab environment only

# ==========================================
# CONFIGURATION
# ==========================================

$tenantDomain = "defensenorthstargmail.onmicrosoft.com"

$displayName = "James Wilson"
$firstName = "James"
$lastName = "Wilson"
$mailNickname = "james.wilson"

$userPrincipalName = "james.wilson@$tenantDomain"

$department = "Engineering"
$jobTitle = "Engineering Manager"

$departmentGroupName = "Engineering"
$roleGroupName = "Engineering Managers"

# ==========================================
# CONNECT TO MICROSOFT GRAPH
# ==========================================

Write-Host ""
Write-Host "Connecting to Microsoft Graph..."

Connect-MgGraph -Scopes `
    "User.ReadWrite.All", `
    "Group.ReadWrite.All"

# ==========================================
# CHECK FOR EXISTING USER
# ==========================================

Write-Host ""
Write-Host "Checking whether $displayName already exists..."

$user = Get-MgUser -Filter "userPrincipalName eq '$userPrincipalName'" `
    -ErrorAction SilentlyContinue

if ($user) {

    Write-Host "$displayName already exists."
    Write-Host "Existing User ID: $($user.Id)"

}
else {

    # ==========================================
    # GENERATE TEMPORARY PASSWORD
    # ==========================================

    $temporaryPassword =
        "Ns!" +
        (Get-Random -Minimum 100000 -Maximum 999999) +
        "Aa#"

    $passwordProfile = @{
        Password = $temporaryPassword
        ForceChangePasswordNextSignIn = $true
    }

    # ==========================================
    # CREATE USER
    # ==========================================

    Write-Host ""
    Write-Host "Creating $displayName..."

    $userParams = @{
        AccountEnabled = $true
        DisplayName = $displayName
        GivenName = $firstName
        Surname = $lastName
        MailNickname = $mailNickname
        UserPrincipalName = $userPrincipalName
        Department = $department
        JobTitle = $jobTitle
        PasswordProfile = $passwordProfile
    }

    $user = New-MgUser -BodyParameter $userParams

    Write-Host ""
    Write-Host "User created successfully."

    Write-Host ""
    Write-Host "Temporary password:"
    Write-Host $temporaryPassword

    Write-Host ""
    Write-Host "SAVE THIS SECURELY."
    Write-Host "Do not place the password in GitHub."
}

# ==========================================
# FIND ENGINEERING GROUP
# ==========================================

Write-Host ""
Write-Host "Finding Engineering group..."

$engineeringGroup =
    Get-MgGroup -Filter "displayName eq '$departmentGroupName'"

if (-not $engineeringGroup) {

    Write-Host "Engineering group was not found."
    Write-Host "Stopping provisioning."

    exit
}

# ==========================================
# FIND OR CREATE ENGINEERING MANAGERS GROUP
# ==========================================

Write-Host ""
Write-Host "Checking Engineering Managers group..."

$managerGroup =
    Get-MgGroup -Filter "displayName eq '$roleGroupName'"

if (-not $managerGroup) {

    Write-Host "Engineering Managers group does not exist."
    Write-Host "Creating group..."

    $managerGroup = New-MgGroup `
        -DisplayName $roleGroupName `
        -Description "Northstar Engineering Manager RBAC group" `
        -MailEnabled:$false `
        -MailNickname "EngineeringManagers" `
        -SecurityEnabled:$true

    Write-Host "Engineering Managers group created."
}
else {

    Write-Host "Engineering Managers group already exists."
}

# ==========================================
# ADD JAMES TO ENGINEERING
# ==========================================

Write-Host ""
Write-Host "Adding James to Engineering..."

$memberReference = @{
    "@odata.id" =
    "https://graph.microsoft.com/v1.0/directoryObjects/$($user.Id)"
}

New-MgGroupMemberByRef `
    -GroupId $engineeringGroup.Id `
    -BodyParameter $memberReference `
    -ErrorAction SilentlyContinue

# ==========================================
# ADD JAMES TO ENGINEERING MANAGERS
# ==========================================

Write-Host "Adding James to Engineering Managers..."

New-MgGroupMemberByRef `
    -GroupId $managerGroup.Id `
    -BodyParameter $memberReference `
    -ErrorAction SilentlyContinue

# ==========================================
# SET JAMES AS SARAH MILLER'S MANAGER
# ==========================================

Write-Host ""
Write-Host "Finding Sarah Miller..."

$sarah =
    Get-MgUser -Filter "displayName eq 'Sarah Miller'"

if ($sarah) {

    $managerReference = @{
        "@odata.id" =
        "https://graph.microsoft.com/v1.0/users/$($user.Id)"
    }

    Set-MgUserManagerByRef `
        -UserId $sarah.Id `
        -BodyParameter $managerReference

    Write-Host "James Wilson assigned as Sarah Miller's manager."
}
else {

    Write-Host "Sarah Miller was not found."
}

# ==========================================
# VERIFICATION
# ==========================================

Write-Host ""
Write-Host "======================================"
Write-Host "PROVISIONING VERIFICATION"
Write-Host "======================================"

$verifiedUser =
    Get-MgUser `
        -UserId $user.Id `
        -Property Id,DisplayName,UserPrincipalName,Department,JobTitle,AccountEnabled

Write-Host ""
Write-Host "Name:        $($verifiedUser.DisplayName)"
Write-Host "UPN:         $($verifiedUser.UserPrincipalName)"
Write-Host "Department:  $($verifiedUser.Department)"
Write-Host "Job Title:   $($verifiedUser.JobTitle)"
Write-Host "Enabled:     $($verifiedUser.AccountEnabled)"

Write-Host ""
Write-Host "Group Memberships:"

Get-MgUserMemberOf -UserId $verifiedUser.Id |
ForEach-Object {

    $group =
        Get-MgGroup `
            -GroupId $_.Id `
            -ErrorAction SilentlyContinue

    if ($group) {
        Write-Host "- $($group.DisplayName)"
    }
}

# ==========================================
# VERIFY SARAH'S MANAGER
# ==========================================

Write-Host ""
Write-Host "Sarah Miller Manager Verification:"

$sarah = Get-MgUser `
    -Filter "displayName eq 'Sarah Miller'" `
    -Property Id,DisplayName

$managerObject =
    Get-MgUserManager `
        -UserId $sarah.Id

$manager =
    Get-MgUser `
        -UserId $managerObject.Id `
        -Property DisplayName,UserPrincipalName,JobTitle,Department

Write-Host "Employee:   $($sarah.DisplayName)"
Write-Host "Manager:    $($manager.DisplayName)"
Write-Host "Role:       $($manager.JobTitle)"
Write-Host "Department: $($manager.Department)"

# ==========================================
# COMPLETE
# ==========================================

Write-Host ""
Write-Host "======================================"
Write-Host "Provisioning completed."
Write-Host "======================================"