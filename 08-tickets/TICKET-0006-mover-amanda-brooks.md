# IAM Ticket IAM-0006

## Request Type

Employee Transfer / Mover

## Employee

Amanda Brooks

Employee ID: NS-1003

## Current Assignment

Department: Engineering

Job Title: Cloud Engineer

Manager: James Wilson

Current RBAC Groups:

- Engineering
- Cloud Engineers

## Requested Assignment

Department: Cybersecurity

Job Title: Cloud Security Engineer

Manager: Jennifer Adams

Required RBAC Groups:

- Cybersecurity
- Cloud Security Engineers

## Access Review

Engineering department access:

Remove

Cloud Engineers access:

Remove

Cybersecurity access:

Approve

Cloud Security Engineers access:

Approve

Global Administrator:

Denied

Permanent privileged access:

Denied

## Security Requirement

Old role access must be removed when the new role becomes effective.

Amanda must not retain Cloud Engineer access after transferring to Cybersecurity.

## Provisioning Tasks

- [x] Validate approved RBAC mapping
- [x] Capture current identity state
- [x] Update department
- [x] Update job title
- [x] Remove Engineering membership
- [x] Remove Cloud Engineers membership
- [x] Add Cybersecurity membership
- [x] Add Cloud Security Engineers membership
- [x] Change manager to Jennifer Adams
- [x] Verify attributes
- [x] Verify group memberships
- [x] Verify manager relationship
- [x] Generate audit record

## Status

Pending Automated Mover Processing - Completed

## Environment

Northstar Defense Systems Lab

## Provisioning Method

Microsoft Graph PowerShell automated Mover workflow.

Automation:

05-automation/process-movers.ps1

Audit Evidence:

07-federal-compliance/audit-logs/mover-audit-log.csv