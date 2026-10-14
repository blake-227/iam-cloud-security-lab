# Northstar Defense Systems
# Access Review Campaign Generator
# Lab environment only

# ============================================================
# CONFIGURATION
# ============================================================

$campaignId = "AR-2026-Q4"

$repoRoot =
    Split-Path -Parent $PSScriptRoot

$scopeFile =
    Join-Path $repoRoot "01-identity\access-review-scope.csv"

$rbacFile =
    Join-Path $repoRoot "01-identity\rbac-role-mapping.csv"

$reviewDirectory =
    Join-Path $repoRoot "07-federal-compliance\access-reviews"

$reviewFile =
    Join-Path $reviewDirectory "$campaignId-access-review.csv"

New-Item `
    -ItemType Directory `
    -Path $reviewDirectory `
    -Force |
    Out-Null

# ============================================================
# CONNECT TO GRAPH
# ============================================================

Write-Host ""
Write-Host "Connecting to Microsoft Graph..."

Connect-MgGraph -Scopes `
    "User.Read.All", `
    "Group.Read.All"

# ============================================================
# LOAD INPUT DATA
# ============================================================

$scope =
    Import-Csv $scopeFile

$rbacMappings =
    Import-Csv $rbacFile

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

$reviewRecords = @()

# ============================================================
# PROCESS USERS
# ============================================================

foreach ($scopeUser in $scope) {

    Write-Host ""
    Write-Host "=================================================="
    Write-Host "Reviewing:"
    Write-Host $scopeUser.UserPrincipalName
    Write-Host "=================================================="

    # ========================================================
    # FIND USER
    # ========================================================

    $user =
        Get-MgUser `
            -Filter "userPrincipalName eq '$($scopeUser.UserPrincipalName)'" `
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

        Write-Host "ERROR: User not found."
        continue
    }

    if ($user.AccountEnabled -eq $false) {

        Write-Host "User is disabled."
        Write-Host "Skipping employee certification."

        continue
    }

    # ========================================================
    # FIND APPROVED RBAC MAPPING
    # ========================================================

    $mapping =
        $rbacMappings |
        Where-Object {

            $_.Department -eq $user.Department -and
            $_.JobTitle -eq $user.JobTitle
        } |
        Select-Object -First 1

    if (-not $mapping) {

        Write-Host ""
        Write-Host "ERROR: No RBAC mapping exists."

        Write-Host "Department:"
        Write-Host $user.Department

        Write-Host "Job title:"
        Write-Host $user.JobTitle

        continue
    }

    $expectedGroups = @(
        $mapping.DepartmentGroup
        $mapping.RoleGroup
    ) |
    Sort-Object -Unique

    # ========================================================
    # FIND MANAGER / REVIEWER
    # ========================================================

    $managerUPN = ""
    $managerName = ""

    try {

        $managerReference =
            Get-MgUserManager `
                -UserId $user.Id `
                -ErrorAction Stop

        $manager =
            Get-MgUser `
                -UserId $managerReference.Id `
                -Property DisplayName,UserPrincipalName

        $managerUPN =
            $manager.UserPrincipalName

        $managerName =
            $manager.DisplayName
    }
    catch {

        $managerUPN = "NO_MANAGER"
        $managerName = "NO_MANAGER"
    }

    # ========================================================
    # GET CURRENT GROUP MEMBERSHIPS
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

    # Only review groups managed by our IAM system

    $managedMemberships =
        $currentGroups |
        Where-Object {

            $_.DisplayName -in $managedGroupNames
        }

    # ========================================================
    # GENERATE CERTIFICATION RECORDS
    # ========================================================

    foreach ($group in $managedMemberships) {

        if ($group.DisplayName -in $expectedGroups) {

            $accessType = "Baseline"
            $recommendation = "Approve"

        }
        else {

            $accessType = "Unexpected"
            $recommendation = "Revoke"
        }

        $reviewRecords +=
            [PSCustomObject]@{

                CampaignID =
                    $campaignId

                UserPrincipalName =
                    $user.UserPrincipalName

                DisplayName =
                    $user.DisplayName

                EmployeeID =
                    $user.EmployeeId

                Department =
                    $user.Department

                JobTitle =
                    $user.JobTitle

                ReviewerName =
                    $managerName

                ReviewerUPN =
                    $managerUPN

                GroupName =
                    $group.DisplayName

                AccessType =
                    $accessType

                Recommendation =
                    $recommendation

                Decision =
                    ""

                ReviewerJustification =
                    ""

                Status =
                    "Pending Review"
            }

        Write-Host ""
        Write-Host "$($user.DisplayName) -> $($group.DisplayName)"

        Write-Host "Access type:"
        Write-Host $accessType

        Write-Host "Recommendation:"
        Write-Host $recommendation
    }
}

# ============================================================
# EXPORT CAMPAIGN
# ============================================================

$reviewRecords |
    Export-Csv `
        -Path $reviewFile `
        -NoTypeInformation

Write-Host ""
Write-Host "=================================================="
Write-Host "ACCESS REVIEW CAMPAIGN GENERATED"
Write-Host "=================================================="

Write-Host ""
Write-Host "Campaign:"
Write-Host $campaignId

Write-Host ""
Write-Host "Review records:"
Write-Host $reviewRecords.Count

Write-Host ""
Write-Host "Output:"
Write-Host $reviewFile