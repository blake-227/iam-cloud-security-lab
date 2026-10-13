# Northstar Defense Systems
# Automated Leaver Workflow
# Lab environment only

# ============================================================
# CONFIGURATION
# ============================================================

$DryRun = $false

$tenantDomain = "defensenorthstargmail.onmicrosoft.com"

$repoRoot = Split-Path -Parent $PSScriptRoot

$leaverFile =
    Join-Path $repoRoot "01-identity\leavers.csv"

$rbacFile =
    Join-Path $repoRoot "01-identity\rbac-role-mapping.csv"

$auditDirectory =
    Join-Path $repoRoot "07-federal-compliance\audit-logs"

$auditFile =
    Join-Path $auditDirectory "leaver-audit-log.csv"

New-Item `
    -ItemType Directory `
    -Path $auditDirectory `
    -Force |
    Out-Null

# Accounts that automation must NEVER disable

$protectedUPNs = @(
    "blake.admin@$tenantDomain"
)

# ============================================================
# CONNECT TO MICROSOFT GRAPH
# ============================================================

Write-Host ""
Write-Host "Connecting to Microsoft Graph..."

Connect-MgGraph -Scopes `
    "User.ReadWrite.All", `
    "Group.ReadWrite.All", `
    "User.RevokeSessions.All"

# ============================================================
# LOAD DATA
# ============================================================

$leavers =
    Import-Csv $leaverFile

$rbacMappings =
    Import-Csv $rbacFile

# Build list of groups managed by Northstar IAM automation

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
# PROCESS LEAVERS
# ============================================================

foreach ($leaver in $leavers) {

    Write-Host ""
    Write-Host "=================================================="
    Write-Host "LEAVER REQUEST"
    Write-Host "Ticket: $($leaver.TicketID)"
    Write-Host "Employee: $($leaver.UserPrincipalName)"
    Write-Host "=================================================="

    # ========================================================
    # PROTECTED ACCOUNT CHECK
    # ========================================================

    if ($leaver.UserPrincipalName -in $protectedUPNs) {

        Write-Host ""
        Write-Host "CRITICAL SAFETY BLOCK:"
        Write-Host "Protected administrative account detected."
        Write-Host "No changes were made."

        continue
    }

    # ========================================================
    # FIND USER
    # ========================================================

    $user =
        Get-MgUser `
        -Filter "userPrincipalName eq '$($leaver.UserPrincipalName)'" `
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

        Write-Host ""
        Write-Host "ERROR: Employee not found."

        continue
    }

    # ========================================================
    # VALIDATE EMPLOYEE ID
    # ========================================================

    if ($user.EmployeeId -ne $leaver.EmployeeID) {

        Write-Host ""
        Write-Host "ERROR: Employee ID mismatch."

        Write-Host "Expected:"
        Write-Host $leaver.EmployeeID

        Write-Host "Found:"
        Write-Host $user.EmployeeId

        continue
    }

    # ========================================================
    # CAPTURE CURRENT GROUP MEMBERSHIPS
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

    # Only groups managed by our IAM system may be removed

    $managedGroupsToRemove =
        $currentGroups |
        Where-Object {

            $_.DisplayName -in $managedGroupNames
        }

    # ========================================================
    # DISPLAY CURRENT STATE
    # ========================================================

    Write-Host ""
    Write-Host "CURRENT IDENTITY STATE"
    Write-Host "----------------------"

    Write-Host "Name:       $($user.DisplayName)"
    Write-Host "EmployeeID: $($user.EmployeeId)"
    Write-Host "Department: $($user.Department)"
    Write-Host "Job Title:  $($user.JobTitle)"
    Write-Host "Enabled:    $($user.AccountEnabled)"

    Write-Host ""
    Write-Host "CURRENT GROUPS"
    Write-Host "--------------"

    if ($currentGroups) {

        $currentGroups |
        ForEach-Object {

            Write-Host "- $($_.DisplayName)"
        }
    }
    else {

        Write-Host "None"
    }

    Write-Host ""
    Write-Host "IAM-MANAGED GROUPS TO REMOVE"
    Write-Host "----------------------------"

    if ($managedGroupsToRemove) {

        $managedGroupsToRemove |
        ForEach-Object {

            Write-Host "- $($_.DisplayName)"
        }
    }
    else {

        Write-Host "None"
    }

    Write-Host ""
    Write-Host "PLANNED ACTIONS"
    Write-Host "---------------"

    Write-Host "- Disable Entra account"
    Write-Host "- Revoke sign-in sessions"
    Write-Host "- Remove IAM-managed groups"
    Write-Host "- Preserve identity for retention"
    Write-Host "- Generate audit evidence"

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
    # EXECUTE LEAVER WORKFLOW
    # ========================================================

    $removedGroups = @()

    try {

        # ====================================================
        # DISABLE ACCOUNT
        # ====================================================

        Write-Host ""
        Write-Host "Disabling account..."

        Update-MgUser `
            -UserId $user.Id `
            -AccountEnabled:$false

        Write-Host "Account disabled."

        # ====================================================
        # REVOKE ACTIVE SIGN-IN SESSIONS
        # ====================================================

        Write-Host ""
        Write-Host "Revoking active sign-in sessions..."

        $sessionResult =
            Revoke-MgUserSignInSession `
                -UserId $user.Id

        Write-Host "Session revocation requested."

        # ====================================================
        # REMOVE IAM-MANAGED ACCESS
        # ====================================================

        Write-Host ""
        Write-Host "Removing IAM-managed access..."

        foreach ($group in $managedGroupsToRemove) {

            Write-Host "Removing $($group.DisplayName)..."

            try {

                Remove-MgGroupMemberByRef `
                    -GroupId $group.Id `
                    -DirectoryObjectId $user.Id `
                    -Confirm:$false `
                    -ErrorAction Stop

                $removedGroups += $group.DisplayName
            }
            catch {

                Write-Host "Unable to remove:"
                Write-Host $group.DisplayName

                Write-Host $_.Exception.Message
            }
        }

        # ====================================================
        # VERIFY ACCOUNT
        # ====================================================

        Write-Host ""
        Write-Host "Verifying deprovisioning..."

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

        $finalGroups = @()

        Get-MgUserMemberOf -UserId $user.Id |
        ForEach-Object {

            $group =
                Get-MgGroup `
                    -GroupId $_.Id `
                    -ErrorAction SilentlyContinue

            if ($group) {

                $finalGroups += $group.DisplayName
            }
        }

        $remainingManagedGroups =
            $finalGroups |
            Where-Object {

                $_ -in $managedGroupNames
            }

        # ====================================================
        # DETERMINE FINAL RESULT
        # ====================================================

        if (
            $verifiedUser.AccountEnabled -eq $false -and
            -not $remainingManagedGroups
        ) {

            $result = "SUCCESS"
        }
        else {

            $result = "REVIEW REQUIRED"
        }

        # ====================================================
        # WRITE AUDIT RECORD
        # ====================================================

        $auditRecord = [PSCustomObject]@{

            Timestamp =
                (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")

            TicketID =
                $leaver.TicketID

            EmployeeID =
                $leaver.EmployeeID

            UserPrincipalName =
                $user.UserPrincipalName

            TerminationDate =
                $leaver.TerminationDate

            Reason =
                $leaver.Reason

            Department =
                $user.Department

            JobTitle =
                $user.JobTitle

            PreviousGroups =
                ($currentGroups.DisplayName -join "; ")

            RemovedGroups =
                ($removedGroups -join "; ")

            RemainingGroups =
                ($finalGroups -join "; ")

            AccountEnabled =
                $verifiedUser.AccountEnabled

            SessionsRevoked =
                $sessionResult

            Result =
                $result
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
        Write-Host "LEAVER PROCESS COMPLETED"
        Write-Host "=================================================="

        Write-Host ""
        Write-Host "Name: $($verifiedUser.DisplayName)"

        Write-Host "Account Enabled:"
        Write-Host $verifiedUser.AccountEnabled

        Write-Host ""
        Write-Host "Removed IAM Groups:"

        if ($removedGroups) {

            $removedGroups |
            ForEach-Object {

                Write-Host "- $_"
            }
        }
        else {

            Write-Host "None"
        }

        Write-Host ""
        Write-Host "Remaining Groups:"

        if ($finalGroups) {

            $finalGroups |
            ForEach-Object {

                Write-Host "- $_"
            }
        }
        else {

            Write-Host "None"
        }

        Write-Host ""
        Write-Host "Result:"
        Write-Host $result

        Write-Host ""
        Write-Host "Audit evidence:"
        Write-Host $auditFile
    }
    catch {

        Write-Host ""
        Write-Host "LEAVER WORKFLOW FAILED:"
        Write-Host $_.Exception.Message

        $failureRecord = [PSCustomObject]@{

            Timestamp =
                (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")

            TicketID =
                $leaver.TicketID

            EmployeeID =
                $leaver.EmployeeID

            UserPrincipalName =
                $leaver.UserPrincipalName

            TerminationDate =
                $leaver.TerminationDate

            Reason =
                $leaver.Reason

            Department =
                $user.Department

            JobTitle =
                $user.JobTitle

            PreviousGroups =
                ($currentGroups.DisplayName -join "; ")

            RemovedGroups =
                ($removedGroups -join "; ")

            RemainingGroups =
                ""

            AccountEnabled =
                "UNKNOWN"

            SessionsRevoked =
                "UNKNOWN"

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