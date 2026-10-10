# IAM Ticket IAM-0002

## Request Type

New Hire Onboarding

## Employee

James Wilson

Employee ID: NS-1002

Department: Engineering

Role: Engineering Manager

Employment Type: Full-Time

---

## Business Request

Provision approved identity and role-based access for James Wilson.

James will manage the Engineering department and supervise Cloud Engineer Sarah Miller.

---

## Approved Access

- Microsoft Entra ID account
- Engineering security group
- Engineering Managers security group
- AWS ReadOnly access
- Azure Reader access
- Engineering Git repositories
- Corporate VPN
- MFA required

---

## Least Privilege Review

AWS AdministratorAccess:

Denied

Azure Owner:

Denied

Global Administrator:

Denied

Permanent privileged access:

Denied

Engineering Manager RBAC access:

Approved

---

## Provisioning Tasks

- [x] Create Entra user
- [x] Set department to Engineering
- [x] Set job title to Engineering Manager
- [x] Add to Engineering group
- [x] Create Engineering Managers group if needed
- [x] Add to Engineering Managers group
- [x] Set James Wilson as Sarah Miller's manager
- [x] Verify account
- [x] Verify group memberships
- [x] Verify manager relationship
- [ ] Require MFA
- [ ] Assign AWS access
- [ ] Assign Azure access
- [ ] Assign Git access
- [ ] Assign VPN access

---

## Status

Identity Provisioning Complete


## Provisioning Method

Provisioned through Microsoft Graph PowerShell automation.

Script:

05-automation/provision-james-wilson.ps1

IAM Analyst: Blake Alvarez

Environment: Northstar Defense Systems Lab