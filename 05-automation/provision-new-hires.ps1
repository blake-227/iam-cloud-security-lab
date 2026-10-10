# Northstar Defense Systems
# Generic Joiner Provisioning Engine
# Lab environment only

# ============================================================
# CONFIGURATION
# ============================================================

$tenantDomain = "defensenorthstargmail.onmicrosoft.com"

$repoRoot = Split-Path -Parent $PSScriptRoot

$newHireFile = Join-Path $repoRoot "01-identity\new-hires.csv"
$rbacFile    = Join-Path $repoRoot "01-identity\rbac-role-mapping.csv"

# ============================================================
# CONNECT TO MICROSOFT GRAPH
# ============================================================

Write-Host ""
Write-Host "Connecting to Microsoft Graph..."

Connect-MgGraph -Scopes `
    "User.ReadWrite.All", `
    "Group.ReadWrite.All"

# ============================================================
# IMPORT DATA
# ============================================================

Write-Host ""
Write-Host "Loading HR intake file and RBAC mapping..."

$newHires = Import-Csv $newHireFile
$rbacMappings = Import-Csv $rbacFile

Write-Host "New hires loaded: $($newHires.Count)"

# ============================================================
# PROCESS EACH EMPLOYEE
# ============================================================

foreach ($employee in $newHires) {

    Write-Host ""
    Write-Host "=================================================="
    Write-Host "Processing $($employee.FirstName) $($employee.LastName)"
    Write-Host "Employee ID: $($employee.EmployeeID)"
    Write-Host "=================================================="

    $displayName = "$($employee.FirstName) $($employee.LastName)"

    $mailNickname =
        "$($employee.FirstName).$($employee.LastName)".ToLower()

    $userPrincipalName =
        "$mailNickname@$tenantDomain"

    # ========================================================
    # LOOK UP APPROVED RBAC ROLE
    # ========================================================

    $mapping =
        $rbacMappings |
        Where-Object {
            $_.JobTitle -eq $employee.JobTitle -and
            $_.Department -eq $employee.Department
        } |
        Select-Object -First 1

    if (-not $mapping) {

        Write-Host ""
        Write-Host "ERROR: No approved RBAC mapping exists."
        Write-Host "Job Title: $($employee.JobTitle)"
        Write-Host "Department: $($employee.Department)"
        Write-Host ""
        Write-Host "Provisioning skipped."

        continue
    }

    Write-Host ""
    Write-Host "Approved RBAC mapping found."
    Write-Host "Department Group: $($mapping.DepartmentGroup)"
    Write-Host "Role Group: $($mapping.RoleGroup)"

    # ========================================================
    # VERIFY REQUIRED GROUPS EXIST
    # ========================================================

    $departmentGroup =
        Get-MgGroup `
        -Filter "displayName eq '$($mapping.DepartmentGroup)'" |
        Select-Object -First 1

    $roleGroup =
        Get-MgGroup `
        -Filter "displayName eq '$($mapping.RoleGroup)'" |
        Select-Object -First 1

    if (-not $departmentGroup) {

        Write-Host ""
        Write-Host "ERROR: Department group not found:"
        Write-Host $mapping.DepartmentGroup
        Write-Host "Provisioning skipped."

        continue
    }

    if (-not $roleGroup) {

        Write-Host ""
        Write-Host "ERROR: Role group not found:"
        Write-Host $mapping.RoleGroup
        Write-Host "Provisioning skipped."

        continue
    }

    # ========================================================
    # CHECK WHETHER USER ALREADY EXISTS
    # ========================================================

    $user =
        Get-MgUser `
        -Filter "userPrincipalName eq '$userPrincipalName'" `
        -ErrorAction SilentlyContinue |
        Select-Object -First 1

    if ($user) {

        Write-Host ""
        Write-Host "$displayName already exists."
        Write-Host "Skipping account creation."

    }
    else {

        # ====================================================
        # GENERATE TEMPORARY PASSWORD
        # ====================================================

        $randomPart =
            [Guid]::NewGuid().ToString("N").Substring(0,12)

        $temporaryPassword =
            "Ns!${randomPart}Aa7#"

        $passwordProfile = @{
            Password = $temporaryPassword
            ForceChangePasswordNextSignIn = $true
        }

        # ====================================================
        # CREATE USER
        # ====================================================

        Write-Host ""
        Write-Host "Creating account..."

        $userParams = @{

            AccountEnabled = $true

            DisplayName = $displayName

            GivenName = $employee.FirstName

            Surname = $employee.LastName

            MailNickname = $mailNickname

            UserPrincipalName = $userPrincipalName

            Department = $employee.Department

            JobTitle = $employee.JobTitle

            EmployeeId = $employee.EmployeeID

            PasswordProfile = $passwordProfile
        }

        try {

            $user =
                New-MgUser `
                -BodyParameter $userParams `
                -ErrorAction Stop

            Write-Host "Account created successfully."

            Write-Host ""
            Write-Host "Temporary password:"
            Write-Host $temporaryPassword

            Write-Host ""
            Write-Host "Store securely."
            Write-Host "Never place this password in GitHub."

        }
        catch {

            Write-Host ""
            Write-Host "ERROR creating user:"
            Write-Host $_.Exception.Message

            continue
        }
    }

    # ========================================================
    # ADD USER TO DEPARTMENT GROUP
    # ========================================================

    Write-Host ""
    Write-Host "Assigning department access..."

    $memberReference = @{
        "@odata.id" =
        "https://graph.microsoft.com/v1.0/directoryObjects/$($user.Id)"
    }

    try {

        New-MgGroupMemberByRef `
            -GroupId $departmentGroup.Id `
            -BodyParameter $memberReference `
            -ErrorAction Stop

        Write-Host "Added to $($mapping.DepartmentGroup)."

    }
    catch {

        Write-Host "Department membership already exists or could not be added."
    }

    # ========================================================
    # ADD USER TO ROLE GROUP
    # ========================================================

    Write-Host ""
    Write-Host "Assigning RBAC role..."

    try {

        New-MgGroupMemberByRef `
            -GroupId $roleGroup.Id `
            -BodyParameter $memberReference `
            -ErrorAction Stop

        Write-Host "Added to $($mapping.RoleGroup)."

    }
    catch {

        Write-Host "Role membership already exists or could not be added."
    }

    # ========================================================
    # SET MANAGER
    # ========================================================

    if ($employee.ManagerUPN) {

        Write-Host ""
        Write-Host "Looking up manager..."

        $manager =
            Get-MgUser `
            -Filter "userPrincipalName eq '$($employee.ManagerUPN)'" `
            -ErrorAction SilentlyContinue |
            Select-Object -First 1

        if ($manager) {

            $managerReference = @{
                "@odata.id" =
                "https://graph.microsoft.com/v1.0/users/$($manager.Id)"
            }

            try {

                Set-MgUserManagerByRef `
                    -UserId $user.Id `
                    -BodyParameter $managerReference `
                    -ErrorAction Stop

                Write-Host "Manager assigned:"
                Write-Host $manager.DisplayName

            }
            catch {

                Write-Host "Manager assignment failed."
                Write-Host $_.Exception.Message
            }

        }
        else {

            Write-Host ""
            Write-Host "WARNING: Manager was not found:"
            Write-Host $employee.ManagerUPN
        }
    }

    # ========================================================
    # VERIFY ACCOUNT
    # ========================================================

    Write-Host ""
    Write-Host "Verifying identity..."

    $verifiedUser =
        Get-MgUser `
            -UserId $user.Id `
            -Property `
                DisplayName,
                UserPrincipalName,
                Department,
                JobTitle,
                EmployeeId,
                AccountEnabled

    Write-Host ""
    Write-Host "Name:        $($verifiedUser.DisplayName)"
    Write-Host "UPN:         $($verifiedUser.UserPrincipalName)"
    Write-Host "Employee ID: $($verifiedUser.EmployeeId)"
    Write-Host "Department:  $($verifiedUser.Department)"
    Write-Host "Job Title:   $($verifiedUser.JobTitle)"
    Write-Host "Enabled:     $($verifiedUser.AccountEnabled)"

    # ========================================================
    # VERIFY GROUP MEMBERSHIP
    # ========================================================

    Write-Host ""
    Write-Host "Group Memberships:"

    Get-MgUserMemberOf -UserId $user.Id |
        ForEach-Object {

            $group =
                Get-MgGroup `
                    -GroupId $_.Id `
                    -ErrorAction SilentlyContinue

            if ($group) {

                Write-Host "- $($group.DisplayName)"
            }
        }

    Write-Host ""
    Write-Host "Provisioning completed for $displayName."
}

Write-Host ""
Write-Host "=================================================="
Write-Host "Northstar Joiner batch completed."
Write-Host "=================================================="