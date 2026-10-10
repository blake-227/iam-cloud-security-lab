# Engineering Log

## Day 1

### IAM
- Created Northstar Defense Systems lab environment.
- Created initial RBAC access matrix.
- Processed first simulated joiner request.
- Applied least privilege principles.
- Documented MFA and access review requirements.

### Cloud
- Defined AWS and Azure services that will make up the Northstar environment.

### Cloud Security
- Established initial access-control requirements for cloud engineers.

### Portfolio
- Created GitHub IAM + Cloud Security portfolio repository.
- Created lab folder structure.
- Added security-focused .gitignore configuration.



## September 17, 2026

### IAM

Created Northstar's initial RBAC access matrix.

Defined access levels for:
- Cloud Engineers
- IAM Engineers
- Security Analysts
- Developers
- Systems Administrators
- Help Desk
- Finance
- HR
- Contractors
- Executives

Processed IAM-0001 for new employee Sarah Miller.

Reviewed requested permissions against the RBAC model.

Denied unnecessary administrative permissions based on least privilege.

Created a 90-day access review.

### Skills Practiced

- RBAC
- Joiner lifecycle
- Least privilege
- Access approval
- Access documentation
- IAM ticket processing
- Audit trail creation



## Day 2 - October 9, 2026

### IAM

- Configured the Northstar Microsoft Entra ID tenant.
- Created a dedicated Blake Admin account.
- Assigned Blake Admin the Global Administrator role.
- Created Sarah Miller as a Cloud Engineer in Microsoft Entra ID.
- Created the Engineering security group.
- Created the Cloud Engineers security group.
- Added Sarah Miller to Engineering and Cloud Engineers.
- Created James Wilson as an Engineering Manager.
- Created the Engineering Managers security group.
- Added James Wilson to Engineering and Engineering Managers.
- Set James Wilson as Sarah Miller's manager.
- Updated IAM-0001 and IAM-0002 with completed identity provisioning tasks.

### Automation

- Installed the Microsoft Graph PowerShell SDK.
- Connected to Microsoft Graph using PowerShell.
- Queried Sarah Miller and James Wilson through Microsoft Graph.
- Verified group memberships through PowerShell.
- Created a PowerShell script to retrieve a user's group memberships.
- Created an automated provisioning script for James Wilson.
- Automated user creation, department assignment, job title assignment, group membership, and manager assignment.
- Added verification logic to the provisioning script.

### Troubleshooting

- Resolved the Microsoft Entra tenant access issue caused by the original Microsoft Services tenant.
- Created a usable Microsoft Entra tenant for the Northstar lab.
- Fixed a PowerShell verification error caused by the user ID not being returned after a Graph query.
- Updated the Graph user query to explicitly request the Id, Department, and AccountEnabled properties.
- Verified that James Wilson belongs to Engineering and Engineering Managers.
- Verified Sarah Miller's manager relationship through Microsoft Graph.
- Resolved the issue where Microsoft Graph initially displayed only the manager object ID instead of the manager's name.

### Cloud Security

- Applied least privilege by denying unnecessary administrative access in the IAM access model.
- Separated the dedicated administrative identity from standard employee identities.
- Used security groups to manage access instead of assigning permissions directly to individual users.

### Skills Practiced

- Microsoft Entra ID
- Microsoft Graph
- PowerShell
- User provisioning
- Joiner lifecycle management
- RBAC
- Security groups
- Group-based access
- Least privilege
- Manager relationships
- IAM verification
- IAM troubleshooting
- IAM ticket processing
- PowerShell automation



## Day 3 - October 10, 2026

### IAM Automation

Built Northstar's first reusable Joiner provisioning workflow.

The workflow now reads HR employee information from CSV and maps each employee's department and job title to an approved RBAC model.

The automation performs:

- User creation
- Employee ID assignment
- Department assignment
- Job title assignment
- Department-based group membership
- Role-based group membership
- Manager assignment
- Identity verification
- Access verification
- Duplicate account protection
- Invalid role rejection

### Testing

Successfully tested:

- Valid employee onboarding
- Duplicate provisioning attempt
- Invalid RBAC role request
- Batch onboarding

### Skills Practiced

- Microsoft Graph
- PowerShell
- IAM automation
- Joiner lifecycle
- RBAC
- Least privilege
- Identity attributes
- Group-based provisioning
- Manager relationships
- Input validation
- Idempotent automation

