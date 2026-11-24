# Northstar Defense Systems
# PAM Expiration / Revocation Engine

$repoRoot =
    Split-Path -Parent $PSScriptRoot

$assignmentFile =
    Join-Path `
        $repoRoot `
        "07-federal-compliance\audit-logs\pam-active-assignments.csv"

$auditFile =
    Join-Path `
        $repoRoot `
        "07-federal-compliance\audit-logs\pam-audit-log.csv"


Connect-MgGraph -Scopes `
    "RoleManagement.ReadWrite.Directory"


$assignments =
    Import-Csv $assignmentFile

$now =
    (Get-Date).ToUniversalTime()


foreach ($assignment in $assignments) {

    if ($assignment.Status -ne "Active") {

        continue
    }


    $expiration =
        [datetime]::Parse(
            $assignment.ExpiresAtUTC
        ).ToUniversalTime()


    if ($expiration -gt $now) {

        Write-Host ""
        Write-Host "$($assignment.RequestID) is still active."

        continue
    }


    Write-Host ""
    Write-Host "Revoking expired access:"
    Write-Host $assignment.RoleName
    Write-Host $assignment.PrivilegedUPN


    try {

        Remove-MgRoleManagementDirectoryRoleAssignment `
            -UnifiedRoleAssignmentId $assignment.AssignmentID `
            -ErrorAction Stop


        $assignment.Status =
            "Expired - Revoked"


        $auditRecord =
            [PSCustomObject]@{

                TimestampUTC =
                    (Get-Date).ToUniversalTime().ToString("o")

                RequestID =
                    $assignment.RequestID

                TicketID =
                    $assignment.TicketID

                PrivilegedUPN =
                    $assignment.PrivilegedUPN

                RoleName =
                    $assignment.RoleName

                AssignmentID =
                    $assignment.AssignmentID

                Action =
                    "Privilege Removed"

                Result =
                    "SUCCESS"
            }


        $auditRecord |
            Export-Csv `
                -Path $auditFile `
                -Append `
                -NoTypeInformation


        Write-Host "Privilege revoked successfully."
    }
    catch {

        Write-Host ""
        Write-Host "ERROR removing role:"
        Write-Host $_.Exception.Message
    }
}


$assignments |
    Export-Csv `
        -Path $assignmentFile `
        -NoTypeInformation