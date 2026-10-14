# Northstar Defense Systems
# Access Review Decision Remediation
# Lab environment only

# ============================================================
# CONFIGURATION
# ============================================================

$DryRun = $true

$campaignId =
    "AR-2026-Q4"

$repoRoot =
    Split-Path -Parent $PSScriptRoot

$reviewFile =
    Join-Path `
        $repoRoot `
        "07-federal-compliance\access-reviews\$campaignId-access-review.csv"

$auditDirectory =
    Join-Path `
        $repoRoot `
        "07-federal-compliance\audit-logs"

$auditFile =
    Join-Path `
        $auditDirectory `
        "access-review-remediation-audit.csv"

New-Item `
    -ItemType Directory `
    -Path $auditDirectory `
    -Force |
    Out-Null

# ============================================================
# CONNECT
# ============================================================

Write-Host ""
Write-Host "Connecting to Microsoft Graph..."

Connect-MgGraph -Scopes `
    "User.Read.All", `
    "Group.ReadWrite.All"

# ============================================================
# LOAD CAMPAIGN
# ============================================================

$reviews =
    Import-Csv $reviewFile

$auditRecords = @()

# ============================================================
# PROCESS DECISIONS
# ============================================================

foreach ($review in $reviews) {

    Write-Host ""
    Write-Host "=================================================="
    Write-Host "$($review.DisplayName)"
    Write-Host "$($review.GroupName)"
    Write-Host "=================================================="

    if ($review.Status -ne "Pending Review") {

        Write-Host "Already processed."
        continue
    }

    # ========================================================
    # VALIDATE DECISION
    # ========================================================

    if (
        $review.Decision -ne "Approve" -and
        $review.Decision -ne "Revoke"
    ) {

        Write-Host "No valid decision."
        Write-Host "Skipping."

        continue
    }

    # ========================================================
    # APPROVE
    # ========================================================

    if ($review.Decision -eq "Approve") {

        Write-Host ""
        Write-Host "Decision: APPROVE"

        $review.Status =
            "Certified"

        $auditRecords +=
            [PSCustomObject]@{

                Timestamp =
                    (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")

                CampaignID =
                    $review.CampaignID

                UserPrincipalName =
                    $review.UserPrincipalName

                GroupName =
                    $review.GroupName

                Reviewer =
                    $review.ReviewerUPN

                Decision =
                    "Approve"

                Action =
                    "Access retained"

                Result =
                    "CERTIFIED"
            }

        continue
    }

    # ========================================================
    # REVOKE BASELINE RBAC ACCESS
    # ========================================================

    if (
        $review.Decision -eq "Revoke" -and
        $review.AccessType -eq "Baseline"
    ) {

        Write-Host ""
        Write-Host "WARNING:"
        Write-Host "Reviewer requested removal of baseline RBAC access."

        Write-Host ""
        Write-Host "Automatic removal blocked."

        Write-Host ""
        Write-Host "IAM investigation required."

        $review.Status =
            "Manual Review Required"

        $auditRecords +=
            [PSCustomObject]@{

                Timestamp =
                    (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")

                CampaignID =
                    $review.CampaignID

                UserPrincipalName =
                    $review.UserPrincipalName

                GroupName =
                    $review.GroupName

                Reviewer =
                    $review.ReviewerUPN

                Decision =
                    "Revoke"

                Action =
                    "Automatic removal blocked due to RBAC conflict"

                Result =
                    "MANUAL REVIEW"
            }

        continue
    }

    # ========================================================
    # REVOKE UNEXPECTED ACCESS
    # ========================================================

    if (
        $review.Decision -eq "Revoke" -and
        $review.AccessType -eq "Unexpected"
    ) {

        Write-Host ""
        Write-Host "Decision: REVOKE"

        Write-Host "Unexpected entitlement:"
        Write-Host $review.GroupName

        $user =
            Get-MgUser `
                -Filter "userPrincipalName eq '$($review.UserPrincipalName)'" |
            Select-Object -First 1

        $group =
            Get-MgGroup `
                -Filter "displayName eq '$($review.GroupName)'" |
            Select-Object -First 1

        if (-not $user -or -not $group) {

            Write-Host "ERROR locating user or group."

            $review.Status =
                "Remediation Failed"

            continue
        }

        if ($DryRun) {

            Write-Host ""
            Write-Host "DRY RUN:"
            Write-Host "Would remove:"
            Write-Host $review.UserPrincipalName

            Write-Host "From:"
            Write-Host $review.GroupName

            continue
        }

        try {

            Remove-MgGroupMemberByRef `
                -GroupId $group.Id `
                -DirectoryObjectId $user.Id `
                -Confirm:$false `
                -ErrorAction Stop

            Write-Host ""
            Write-Host "Access removed successfully."

            $review.Status =
                "Remediated"

            $auditRecords +=
                [PSCustomObject]@{

                    Timestamp =
                        (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")

                    CampaignID =
                        $review.CampaignID

                    UserPrincipalName =
                        $review.UserPrincipalName

                    GroupName =
                        $review.GroupName

                    Reviewer =
                        $review.ReviewerUPN

                    Decision =
                        "Revoke"

                    Action =
                        "Group membership removed"

                    Result =
                        "SUCCESS"
                }
        }
        catch {

            Write-Host ""
            Write-Host "ERROR:"
            Write-Host $_.Exception.Message

            $review.Status =
                "Remediation Failed"

            $auditRecords +=
                [PSCustomObject]@{

                    Timestamp =
                        (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")

                    CampaignID =
                        $review.CampaignID

                    UserPrincipalName =
                        $review.UserPrincipalName

                    GroupName =
                        $review.GroupName

                    Reviewer =
                        $review.ReviewerUPN

                    Decision =
                        "Revoke"

                    Action =
                        "Attempted group membership removal"

                    Result =
                        "FAILED"
                }
        }
    }
}

# ============================================================
# SAVE UPDATED CAMPAIGN
# ============================================================

if (-not $DryRun) {

    $reviews |
        Export-Csv `
            -Path $reviewFile `
            -NoTypeInformation
}

# ============================================================
# SAVE AUDIT RECORDS
# ============================================================

if ($auditRecords) {

    $auditRecords |
        Export-Csv `
            -Path $auditFile `
            -Append `
            -NoTypeInformation
}

Write-Host ""
Write-Host "=================================================="
Write-Host "ACCESS REVIEW PROCESSING COMPLETE"
Write-Host "=================================================="