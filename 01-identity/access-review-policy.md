# Northstar Access Review Policy

## Purpose

Northstar Defense Systems performs periodic access reviews to verify that employees retain only the access required for their current job responsibilities.

## Review Frequency

Quarterly

## Review Scope

IAM-managed security groups

## Reviewer

Employee's current manager

## Review Decisions

Approve

The access remains appropriate for the employee.

Revoke

The access is no longer required and must be removed.

Manual Review

The requested decision conflicts with the employee's approved RBAC role or requires additional investigation.

## Governance Rules

Access must align with the employee's current department and job title.

Unexpected access should be reviewed for removal.

Managers must provide justification for access exceptions.

Baseline RBAC access should not be automatically removed if the employee's authoritative job role still requires it.

Conflicting decisions must be escalated for manual IAM review.

## Remediation

Rejected non-baseline access may be automatically removed.

Baseline access conflicts require IAM investigation before remediation.

## Evidence Retention

Access review campaign records and remediation logs must be preserved for audit purposes.