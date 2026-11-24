# Northstar Defense Systems
# PAM Activation Engine
# Lab environment only


# ============================================================
# CONFIGURATION
# ============================================================

$DryRun = $false

$repoRoot =
    Split-Path -Parent $PSScriptRoot

$requestFile =
    Join-Path `
        $repoRoot `
        "01-identity\pam-requests.csv"

$roleMatrixFile =
    Join-Path `
        $repoRoot `
        "01-identity\privileged-role-matrix.csv"

$assignmentFile =
    Join-Path `
        $repoRoot `
        "07-federal-compliance\audit-logs\pam-active-assignments.csv"

$auditDirectory =
    Split-Path -Parent $assignmentFile


# ============================================================
# ENSURE AUDIT DIRECTORY EXISTS
# ============================================================

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
    "User.Read.All", `
    "RoleManagement.ReadWrite.Directory"


# ============================================================
# LOAD PAM DATA
# ============================================================

$requests =
    Import-Csv $requestFile

$roleMatrix =
    Import-Csv $roleMatrixFile


# ============================================================
# PROCESS PAM REQUESTS
# ============================================================

foreach ($request in $requests) {

    Write-Host ""
    Write-Host "============================================"
    Write-Host "PAM REQUEST $($request.RequestID)"
    Write-Host "============================================"


    # ========================================================
    # CHECK REQUEST STATUS
    # ========================================================

    if ($request.Status -ne "Pending") {

        Write-Host "Request already processed."
        continue
    }


    # ========================================================
    # CHECK APPROVAL
    # ========================================================

    if ($request.Decision -ne "Approve") {

        Write-Host "Request is not approved."
        continue
    }


    # ========================================================
    # VALIDATE PAM POLICY
    # ========================================================

    $approvedRole =
        $roleMatrix |
        Where-Object {

            $_.RoleName -eq $request.RoleName -and
            $_.AllowedPrivilegedAccount -eq $request.PrivilegedUPN

        } |
        Select-Object -First 1


    if (-not $approvedRole) {

        Write-Host ""
        Write-Host "DENIED:"
        Write-Host "Role or privileged identity is not approved by PAM policy."

        continue
    }


    # ========================================================
    # VALIDATE REQUESTED DURATION
    # ========================================================

    if (
        [int]$request.DurationMinutes -gt
        [int]$approvedRole.MaximumDurationMinutes
    ) {

        Write-Host ""
        Write-Host "DENIED:"
        Write-Host "Requested duration exceeds PAM maximum."

        continue
    }


    # ========================================================
    # FIND PRIVILEGED USER
    # ========================================================

    $user =
        Get-MgUser `
            -Filter "userPrincipalName eq '$($request.PrivilegedUPN)'" |
        Select-Object -First 1


    if (-not $user) {

        Write-Host ""
        Write-Host "ERROR:"
        Write-Host "Privileged user not found."

        continue
    }


    # ========================================================
    # FIND DIRECTORY ROLE
    # ========================================================

    $roleDefinition =
        Get-MgRoleManagementDirectoryRoleDefinition `
            -Filter "displayName eq '$($request.RoleName)'" |
        Select-Object -First 1


    if (-not $roleDefinition) {

        Write-Host ""
        Write-Host "ERROR:"
        Write-Host "Directory role not found."

        continue
    }


    # ========================================================
    # CHECK FOR EXISTING ROLE ASSIGNMENT
    # ========================================================

    $existingAssignments =
        Get-MgRoleManagementDirectoryRoleAssignment -All |
        Where-Object {

            $_.PrincipalId -eq $user.Id -and
            $_.RoleDefinitionId -eq $roleDefinition.Id
        }


    if ($existingAssignments) {

        Write-Host ""
        Write-Host "STOP:"
        Write-Host "This privileged role is already assigned."

        continue
    }


    # ========================================================
    # DISPLAY PRIVILEGED ACCESS PLAN
    # ========================================================

    Write-Host ""
    Write-Host "PRIVILEGED ACCESS PLAN"
    Write-Host "----------------------"

    Write-Host "Account:"
    Write-Host $request.PrivilegedUPN

    Write-Host ""
    Write-Host "Role:"
    Write-Host $request.RoleName

    Write-Host ""
    Write-Host "Duration:"
    Write-Host "$($request.DurationMinutes) minutes"

    Write-Host ""
    Write-Host "Approver:"
    Write-Host $request.ApproverUPN


    # ========================================================
    # DRY RUN
    # ========================================================

    if ($DryRun) {

        Write-Host ""
        Write-Host "DRY RUN ENABLED."
        Write-Host "No privileged role assigned."

        continue
    }


    # ========================================================
    # ACTIVATE PAM ACCESS
    # ========================================================

    try {

        Write-Host ""
        Write-Host "Assigning privileged role..."


        $assignment =
            New-MgRoleManagementDirectoryRoleAssignment `
                -DirectoryScopeId "/" `
                -PrincipalId $user.Id `
                -RoleDefinitionId $roleDefinition.Id `
                -ErrorAction Stop


        # ====================================================
        # CALCULATE ACTIVATION AND EXPIRATION
        # ====================================================

        $activated =
            (Get-Date).ToUniversalTime()

        $expires =
            $activated.AddMinutes(
                [int]$request.DurationMinutes
            )


        # ====================================================
        # BUILD PAM LEDGER RECORD
        # ====================================================

        $record =
            [PSCustomObject]@{

                RequestID =
                    $request.RequestID

                TicketID =
                    $request.TicketID

                PrivilegedUPN =
                    $request.PrivilegedUPN

                RoleName =
                    $request.RoleName

                AssignmentID =
                    $assignment.Id

                ActivatedAtUTC =
                    $activated.ToString("o")

                ExpiresAtUTC =
                    $expires.ToString("o")

                Status =
                    "Active"
            }


        # ====================================================
        # WRITE PAM ASSIGNMENT LEDGER
        # ====================================================

        if (Test-Path $assignmentFile) {

            $record |
                Export-Csv `
                    -Path $assignmentFile `
                    -Append `
                    -NoTypeInformation
        }
        else {

            $record |
                Export-Csv `
                    -Path $assignmentFile `
                    -NoTypeInformation
        }


        # ====================================================
        # VERIFY LEDGER FILE EXISTS
        # ====================================================

        if (-not (Test-Path $assignmentFile)) {

            throw "PAM assignment ledger was not created."
        }


        # ====================================================
        # VERIFY ASSIGNMENT WAS WRITTEN TO LEDGER
        # ====================================================

        $ledgerCheck =
            Import-Csv $assignmentFile |
            Where-Object {

                $_.AssignmentID -eq $assignment.Id
            }


        if (-not $ledgerCheck) {

            throw "PAM assignment was created in Entra but was not written to the PAM ledger."
        }


        Write-Host ""
        Write-Host "PAM ledger successfully updated."


        # ====================================================
        # UPDATE REQUEST STATUS
        # ====================================================

        $request.Status =
            "Active"


        # ====================================================
        # DISPLAY SUCCESS
        # ====================================================

        Write-Host ""
        Write-Host "============================================"
        Write-Host "PAM ACTIVATION SUCCESSFUL"
        Write-Host "============================================"

        Write-Host ""
        Write-Host "Assignment ID:"
        Write-Host $assignment.Id

        Write-Host ""
        Write-Host "Activated UTC:"
        Write-Host $activated

        Write-Host ""
        Write-Host "Expires UTC:"
        Write-Host $expires
    }
    catch {

        Write-Host ""
        Write-Host "============================================"
        Write-Host "ACTIVATION FAILED"
        Write-Host "============================================"

        Write-Host ""
        Write-Host $_.Exception.Message
    }
}


# ============================================================
# SAVE UPDATED PAM REQUESTS
# ============================================================

if (-not $DryRun) {

    $requests |
        Export-Csv `
            -Path $requestFile `
            -NoTypeInformation
}