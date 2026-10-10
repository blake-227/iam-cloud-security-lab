# Northstar Defense Systems
# IAM User Access Lookup
# Lab script

Connect-MgGraph -Scopes "User.Read.All","Group.Read.All"

$user = Get-MgUser -Filter "displayName eq 'Sarah Miller'"

Write-Host ""
Write-Host "User:"
Write-Host $user.DisplayName

Write-Host ""
Write-Host "User Principal Name:"
Write-Host $user.UserPrincipalName

Write-Host ""
Write-Host "Group Memberships:"

Get-MgUserMemberOf -UserId $user.Id | ForEach-Object {

    $group = Get-MgGroup -GroupId $_.Id -ErrorAction SilentlyContinue

    if ($group) {
        Write-Host $group.DisplayName
    }
}