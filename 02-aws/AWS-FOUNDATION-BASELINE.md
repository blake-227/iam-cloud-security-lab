# Northstar AWS Foundation

## Environment

Organization:

Northstar-lab

Primary workload account:

Moonshot Mode

Primary Region:

us-east-1

## Root Security

Root MFA:

Enabled

Root access keys:

None

Root account usage:

Restricted to root-specific and emergency administrative tasks

## Workforce Authentication

Authentication method:

AWS IAM Identity Center

Identity Center group:

Northstar-Cloud-Admins

Permission set:

Northstar-PowerUser

Workload account:

Moonshot Mode

## AWS CLI

Authentication:

IAM Identity Center / temporary credentials

CLI profile:

northstar-admin

Primary Region:

us-east-1

Validation command:

aws sts get-caller-identity --profile northstar-admin

Validation result:

Successful

## Long-Term Credentials

IAM users for normal workforce administration:

Not used

Long-term access keys:

Not used

## Cost Controls

Monthly AWS budget:

Northstar-Monthly-Lab-Budget

Budget amount:

$10

Alerts:

50 percent

80 percent

100 percent

## Security Model

Root account is not used for normal cloud administration.

Northstar administrators authenticate through IAM Identity Center.

Access to the Moonshot Mode workload account is granted through group membership and permission sets.

AWS CLI access uses temporary Identity Center credentials rather than static access keys.

## Next Milestones

- VPC architecture
- Public subnet
- Private subnet
- Internet Gateway
- Route tables
- Security groups
- EC2
- S3
- CloudTrail
- CloudWatch
- KMS