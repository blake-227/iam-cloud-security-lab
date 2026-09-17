# IAM Ticket IAM-0001

## Request Type

New Hire Onboarding

## Requestor

James Wilson

Engineering Manager

## Employee

Sarah Miller

Employee ID: NS-1001

Department: Engineering

Role: Cloud Engineer

Employment Type: Full-Time

---

## Business Request

Provision required corporate and cloud access for Sarah Miller before her first day.

Requested access:

- Microsoft Entra ID account
- Engineering security group
- Cloud Engineers security group
- AWS Developer access
- Azure Contributor access
- Engineering Git repositories
- Corporate VPN

---

## IAM Analyst Review

### Identity Verification

Employee exists in approved HR onboarding request.

Status:

Approved

### Role Validation

Requested job role:

Cloud Engineer

RBAC role found in:

01-identity/access-matrix.csv

Status:

Approved

### Least Privilege Review

AWS AdministratorAccess:

Denied

Azure Owner:

Denied

Global Administrator:

Denied

Permanent privileged access:

Denied

Standard Cloud Engineer permissions:

Approved

---

## Required Controls

- MFA enabled
- Manager approval recorded
- Role-based access applied
- Least privilege applied
- No shared credentials
- 90-day access review scheduled

---

## Provisioning Tasks

- [ ] Create Entra user
- [ ] Add to Engineering group
- [ ] Add to Cloud Engineers group
- [ ] Assign AWS Developer role
- [ ] Assign Azure Contributor access
- [ ] Grant Git repository access
- [ ] Enable VPN access
- [ ] Require MFA
- [ ] Validate login
- [ ] Document completion

---

## Final Status

Status: Pending Provisioning

IAM Analyst: Blake Alvarez

Environment: Northstar Defense Systems Lab