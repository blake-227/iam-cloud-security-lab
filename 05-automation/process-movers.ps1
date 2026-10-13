# Northstar Defense Systems
# Automated Mover Workflow
# Lab environment only

# ============================================================
# CONFIGURATION
# ============================================================

$DryRun = $false

$repoRoot = Split-Path -Parent $PSScriptRoot

$moverFile =
    Join-Path $repoRoot "01-identity\movers.csv"

$rbacFile =
    Join-Path $repoRoot "01-identity\rbac-role-mapping.csv"

$auditDirectory =
    Join-Path $repoRoot "07-federal-compliance\audit-logs"

$auditFile =
    Join-Path $auditDirectory "mover-audit-log.csv"

New-Item `
    -ItemType Directory `
    -Path $auditDirectory `
    -Force |
    Out-Null

# ============================================================
# CONNECT TO MICROSOFT GRAPH
# ============================================================

Write-Host ""
Write-Host "Connecting to Microsoft Graph..."

Connect-MgGraph -Scopes `
    "User.ReadWrite.All", `
    "Group.ReadWrite.All"

# ============================================================
# LOAD DATA
# ============================================================

$movers =
    Import-Csv $moverFile

$rbacMappings =
    Import-Csv $rbacFile

# Build list of groups controlled by Northstar RBAC automation

$managedGroupNames = @(
    $rbacMappings |
    ForEach-Object {

        $_.DepartmentGroup
        $_.RoleGroup
    }
) |
Where-Object {
    -not [string]::IsNullOrWhiteSpace($_)
} |
Sort-Object -Unique

# ============================================================
# PROCESS MOVERS
# ============================================================

foreach ($move in $movers) {

    Write-Host ""
    Write-Host "=================================================="
    Write-Host "MOVER REQUEST"
    Write-Host "Ticket: $($move.TicketID)"
    Write-Host "Employee: $($move.UserPrincipalName)"
    Write-Host "=================================================="

    # ========================================================
    # FIND USER
    # ========================================================

    $user =
        Get-MgUser `
        -Filter "userPrincipalName eq '$($move.UserPrincipalName)'" `
        -Property `
            Id,
            DisplayName,
            UserPrincipalName,
            EmployeeId,
            Department,
            JobTitle,
            AccountEnabled |
        Select-Object -First 1

    if (-not $user) {

        Write-Host "ERROR: Employee not found."
        continue
    }

    # ========================================================
    # VALIDATE EMPLOYEE ID
    # ========================================================

    if ($user.EmployeeId -ne $move.EmployeeID) {

        Write-Host ""
        Write-Host "ERROR: Employee ID mismatch."
        Write-Host "Expected: $($move.EmployeeID)"
        Write-Host "Found:    $($user.EmployeeId)"

        continue
    }

    # ========================================================
    # FIND APPROVED NEW RBAC MAPPING
    # ========================================================

    $newMapping =
        $rbacMappings |
        Where-Object {

            $_.Department -eq $move.NewDepartment -and
            $_.JobTitle -eq $move.NewJobTitle

        } |
        Select-Object -First 1

    if (-not $newMapping) {

        Write-Host ""
        Write-Host "ERROR: No approved RBAC mapping exists."
        Write-Host "Department: $($move.NewDepartment)"
        Write-Host "Job Title:  $($move.NewJobTitle)"

        continue
    }

    # ========================================================
    # FIND REQUIRED NEW GROUPS
    # ========================================================

    $desiredGroupNames = @(
        $newMapping.DepartmentGroup
        $newMapping.RoleGroup
    ) |
    Sort-Object -Unique

    $desiredGroups = @()

    foreach ($groupName in $desiredGroupNames) {

        $group =
            Get-MgGroup `
            -Filter "displayName eq '$groupName'" |
            Select-Object -First 1

        if (-not $group) {

            Write-Host ""
            Write-Host "ERROR: Required RBAC group does not exist:"
            Write-Host $groupName

            continue 2
        }

        $desiredGroups += $group
    }

    # ========================================================
    # FIND NEW MANAGER
    # ========================================================

    $newManager = $null

    if ($move.NewManagerUPN) {

        $newManager =
            Get-MgUser `
            -Filter "userPrincipalName eq '$($move.NewManagerUPN)'" `
            -Property Id,DisplayName,UserPrincipalName |
            Select-Object -First 1

        if (-not $newManager) {

            Write-Host ""
            Write-Host "ERROR: New manager not found:"
            Write-Host $move.NewManagerUPN

            continue
        }
    }

    # ========================================================
    # CAPTURE CURRENT GROUP MEMBERSHIP
    # ========================================================

    $currentGroups = @()

    Get-MgUserMemberOf -UserId $user.Id |
    ForEach-Object {

        $group =
            Get-MgGroup `
            -GroupId $_.Id `
            -ErrorAction SilentlyContinue

        if ($group) {

            $currentGroups += $group
        }
    }

    # ========================================================
    # CAPTURE CURRENT MANAGER
    # ========================================================

    $oldManagerName = ""

    try {

        $oldManagerReference =
            Get-MgUserManager `
            -UserId $user.Id `
            -ErrorAction Stop

        if ($oldManagerReference) {

            $oldManager =
                Get-MgUser `
                -UserId $oldManagerReference.Id `
                -Property DisplayName,UserPrincipalName

            $oldManagerName =
                $oldManager.UserPrincipalName
        }
    }
    catch {

        $oldManagerName = "None"
    }

    # ========================================================
    # CALCULATE ACCESS CHANGES
    # ========================================================

    $currentManagedGroups =
        $currentGroups |
        Where-Object {

            $_.DisplayName -in $managedGroupNames
        }

    $groupsToRemove =
        $currentManagedGroups |
        Where-Object {

            $_.DisplayName -notin $desiredGroupNames
        }

    $currentGroupIds =
        $currentGroups.Id

    $groupsToAdd =
        $desiredGroups |
        Where-Object {

            $_.Id -notin $currentGroupIds
        }

    # ========================================================
    # SHOW CHANGE PLAN
    # ========================================================

    Write-Host ""
    Write-Host "CURRENT STATE"
    Write-Host "-------------"

    Write-Host "Name:       $($user.DisplayName)"
    Write-Host "Department: $($user.Department)"
    Write-Host "Job Title:  $($user.JobTitle)"
    Write-Host "Manager:    $oldManagerName"

    Write-Host ""
    Write-Host "REQUESTED STATE"
    Write-Host "---------------"

    Write-Host "Department: $($move.NewDepartment)"
    Write-Host "Job Title:  $($move.NewJobTitle)"
    Write-Host "Manager:    $($move.NewManagerUPN)"

    Write-Host ""
    Write-Host "GROUPS TO REMOVE"
    Write-Host "----------------"

    if ($groupsToRemove) {

        $groupsToRemove |
        ForEach-Object {

            Write-Host "- $($_.DisplayName)"
        }
    }
    else {

        Write-Host "None"
    }

    Write-Host ""
    Write-Host "GROUPS TO ADD"
    Write-Host "-------------"

    if ($groupsToAdd) {

        $groupsToAdd |
        ForEach-Object {

            Write-Host "- $($_.DisplayName)"
        }
    }
    else {

        Write-Host "None"
    }

    # ========================================================
    # DRY RUN
    # ========================================================

    if ($DryRun) {

        Write-Host ""
        Write-Host "DRY RUN ENABLED."
        Write-Host "No changes were made."

        continue
    }

    # ========================================================
    # APPLY CHANGES
    # ========================================================

    try {

        Write-Host ""
        Write-Host "Updating user attributes..."

        Update-MgUser `
            -UserId $user.Id `
            -Department $move.NewDepartment `
            -JobTitle $move.NewJobTitle

        # ====================================================
        # REMOVE OLD MANAGED ACCESS
        # ====================================================

        foreach ($group in $groupsToRemove) {

            Write-Host "Removing $($group.DisplayName)..."

            Remove-MgGroupMemberByRef `
                -GroupId $group.Id `
                -DirectoryObjectId $user.Id `
                -Confirm:$false
        }

        # ====================================================
        # ADD NEW ACCESS
        # ====================================================

        foreach ($group in $groupsToAdd) {

            Write-Host "Adding $($group.DisplayName)..."

            $memberReference = @{

                "@odata.id" =
                    "https://graph.microsoft.com/v1.0/directoryObjects/$($user.Id)"
            }

            New-MgGroupMemberByRef `
                -GroupId $group.Id `
                -BodyParameter $memberReference
        }

        # ====================================================
        # UPDATE MANAGER
        # ====================================================

        if ($newManager) {

            Write-Host "Updating manager..."

            $managerReference = @{

                "@odata.id" =
                    "https://graph.microsoft.com/v1.0/users/$($newManager.Id)"
            }

            Set-MgUserManagerByRef `
                -UserId $user.Id `
                -BodyParameter $managerReference
        }

        # ====================================================
        # VERIFY FINAL USER ATTRIBUTES
        # ====================================================

        $verifiedUser =
            Get-MgUser `
            -UserId $user.Id `
            -Property `
                DisplayName,
                UserPrincipalName,
                EmployeeId,
                Department,
                JobTitle,
                AccountEnabled

        # ====================================================
        # VERIFY FINAL GROUPS
        # ====================================================

        $verifiedGroups = @()

        Get-MgUserMemberOf -UserId $user.Id |
        ForEach-Object {

            $group =
                Get-MgGroup `
                    -GroupId $_.Id `
                    -ErrorAction SilentlyContinue

            if ($group) {

                $verifiedGroups +=
                    $group.DisplayName
            }
        }

        # ====================================================
        # VERIFY FINAL MANAGER
        # ====================================================

        $verifiedManagerName = ""

        try {

            $managerReference =
                Get-MgUserManager `
                -UserId $user.Id `
                -ErrorAction Stop

            $managerUser =
                Get-MgUser `
                -UserId $managerReference.Id `
                -Property DisplayName,UserPrincipalName

            $verifiedManagerName =
                $managerUser.UserPrincipalName
        }
        catch {

            $verifiedManagerName =
                "Unable to verify"
        }

        # ====================================================
        # CREATE AUDIT RECORD
        # ====================================================

        $auditRecord = [PSCustomObject]@{

            Timestamp =
                (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")

            TicketID =
                $move.TicketID

            EmployeeID =
                $move.EmployeeID

            UserPrincipalName =
                $user.UserPrincipalName

            OldDepartment =
                $user.Department

            NewDepartment =
                $verifiedUser.Department

            OldJobTitle =
                $user.JobTitle

            NewJobTitle =
                $verifiedUser.JobTitle

            OldManager =
                $oldManagerName

            NewManager =
                $verifiedManagerName

            RemovedGroups =
                ($groupsToRemove.DisplayName -join "; ")

            AddedGroups =
                ($groupsToAdd.DisplayName -join "; ")

            FinalGroups =
                ($verifiedGroups -join "; ")

            Result =
                "SUCCESS"
        }

        $auditRecord |
        Export-Csv `
            -Path $auditFile `
            -Append `
            -NoTypeInformation

        # ====================================================
        # DISPLAY RESULT
        # ====================================================

        Write-Host ""
        Write-Host "=================================================="
        Write-Host "MOVER COMPLETED"
        Write-Host "=================================================="

        Write-Host ""
        Write-Host "Name:       $($verifiedUser.DisplayName)"
        Write-Host "Department: $($verifiedUser.Department)"
        Write-Host "Job Title:  $($verifiedUser.JobTitle)"
        Write-Host "Manager:    $verifiedManagerName"

        Write-Host ""
        Write-Host "Final group memberships:"

        $verifiedGroups |
        ForEach-Object {

            Write-Host "- $_"
        }

        Write-Host ""
        Write-Host "Audit record written to:"
        Write-Host $auditFile
    }
    catch {

        Write-Host ""
        Write-Host "ERROR:"
        Write-Host $_.Exception.Message

        $failureRecord = [PSCustomObject]@{

            Timestamp =
                (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")

            TicketID =
                $move.TicketID

            EmployeeID =
                $move.EmployeeID

            UserPrincipalName =
                $move.UserPrincipalName

            OldDepartment =
                $user.Department

            NewDepartment =
                $move.NewDepartment

            OldJobTitle =
                $user.JobTitle

            NewJobTitle =
                $move.NewJobTitle

            OldManager =
                $oldManagerName

            NewManager =
                $move.NewManagerUPN

            RemovedGroups =
                ""

            AddedGroups =
                ""

            FinalGroups =
                ""

            Result =
                "FAILED: $($_.Exception.Message)"
        }

        $failureRecord |
        Export-Csv `
            -Path $auditFile `
            -Append `
            -NoTypeInformation
    }
}