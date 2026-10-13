# IAM Ticket IAM-0007

## Request Type

Employee Termination / Leaver

## Employee

David Lee

Employee ID: NS-1005

Department: IT

Job Title: Help Desk Technician

## Termination

Effective Date: October 13, 2026

Reason: Voluntary Resignation

## Current Access

Expected IAM-managed groups:

- IT
- Help Desk

## Required Actions

- [x] Validate employee identity
- [x] Capture existing identity state
- [x] Capture current group memberships
- [x] Disable Entra account
- [x] Revoke active sign-in sessions
- [x] Remove IAM-managed group memberships
- [x] Verify account is disabled
- [x] Verify managed access is removed
- [x] Generate audit evidence

## Retention

Do not delete the Entra identity.

Account must remain available for audit and retention purposes.

## Provisioning Method

Microsoft Graph PowerShell automated Leaver workflow.

Automation:

05-automation/process-leavers.ps1

Audit Evidence:

07-federal-compliance/audit-logs/leaver-audit-log.csv

## Status

Pending Automated Deprovisioning - Completed

## Environment

Northstar Defense Systems Lab