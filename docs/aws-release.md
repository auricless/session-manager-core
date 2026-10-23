# AWS CodeArtifact release setup

This repository builds `org.c3cavite:session-manager-core:1.0.0`. It does not create an AWS domain, repository, IAM role, or GitHub variable. The library does not use AWS at runtime. Only the manual [release workflow](../.github/workflows/release.yml) accesses AWS.

## One-time administrator setup

1. Create or select a CodeArtifact domain and Maven repository in one AWS Region. Configure the repository's upstream access to Maven Central if consumers will resolve other dependencies through it.
2. Create an IAM role for GitHub's OpenID Connect (OIDC) provider `token.actions.githubusercontent.com`. Its trust policy must require audience `sts.amazonaws.com` and subject `repo:auricless/session-manager-core:ref:refs/heads/master`. Limit the role to this repository and branch. Use GitHub's [AWS OIDC guidance](https://docs.github.com/en/actions/how-tos/secure-your-work/security-harden-deployments/oidc-in-aws) when setting up the provider and trust policy.
3. Grant the role these minimum release actions, scoped to the domain, repository, and Maven package where AWS supports resource scoping:

   | Action | Resource |
   | --- | --- |
   | `sts:GetServiceBearerToken` | `*`, conditioned on `sts:AWSServiceName = codeartifact.amazonaws.com` |
   | `codeartifact:GetAuthorizationToken` | CodeArtifact domain ARN |
   | `codeartifact:GetRepositoryEndpoint` | CodeArtifact repository ARN |
   | `codeartifact:ReadFromRepository` | CodeArtifact repository ARN, for fresh consumer verification |
   | `codeartifact:DescribePackageVersion` | package ARN for `maven/org.c3cavite/session-manager-core` |
   | `codeartifact:PublishPackageVersion` | same package ARN |
   | `codeartifact:PutPackageMetadata` | same package ARN |

   Maven publishing requires both package write actions. `GetAuthorizationToken` also requires `sts:GetServiceBearerToken`. Repository read access lets the workflow verify the published artifact in a fresh consumer. See [AWS publishing permissions](https://docs.aws.amazon.com/codeartifact/latest/ug/packages-overview.html) and the [CodeArtifact IAM reference](https://docs.aws.amazon.com/codeartifact/latest/ug/auth-and-access-control-permissions-reference.html).

   The following trust policy and identity policy are starting templates. Replace every angle-bracket placeholder with the domain's account, Region, and names before applying them through your normal IAM change process.

   ```json
   {
     "Version": "2012-10-17",
     "Statement": [{
       "Effect": "Allow",
       "Principal": {
         "Federated": "arn:aws:iam::<account-id>:oidc-provider/token.actions.githubusercontent.com"
       },
       "Action": "sts:AssumeRoleWithWebIdentity",
       "Condition": {
         "StringEquals": {
           "token.actions.githubusercontent.com:aud": "sts.amazonaws.com",
           "token.actions.githubusercontent.com:sub": "repo:auricless/session-manager-core:ref:refs/heads/master"
         }
       }
     }]
   }
   ```

   ```json
   {
     "Version": "2012-10-17",
     "Statement": [
       {
         "Effect": "Allow",
         "Action": "sts:GetServiceBearerToken",
         "Resource": "*",
         "Condition": {
           "StringEquals": {
             "sts:AWSServiceName": "codeartifact.amazonaws.com"
           }
         }
       },
       {
         "Effect": "Allow",
         "Action": "codeartifact:GetAuthorizationToken",
         "Resource": "arn:aws:codeartifact:<region>:<account-id>:domain/<domain>"
       },
       {
         "Effect": "Allow",
         "Action": ["codeartifact:GetRepositoryEndpoint", "codeartifact:ReadFromRepository"],
         "Resource": "arn:aws:codeartifact:<region>:<account-id>:repository/<domain>/<repository>"
       },
       {
         "Effect": "Allow",
         "Action": [
           "codeartifact:DescribePackageVersion",
           "codeartifact:PublishPackageVersion",
           "codeartifact:PutPackageMetadata"
         ],
         "Resource": "arn:aws:codeartifact:<region>:<account-id>:package/<domain>/<repository>/maven/org.c3cavite/session-manager-core"
       }
     ]
   }
   ```
4. Set these **GitHub repository variables** in `auricless/session-manager-core` (Settings → Secrets and variables → Actions → Variables):

   | Variable | Value |
   | --- | --- |
   | `AWS_ROLE_ARN` | ARN of the OIDC release role |
   | `AWS_REGION` | Region containing the domain |
   | `CODEARTIFACT_DOMAIN` | Domain name |
   | `CODEARTIFACT_DOMAIN_OWNER` | 12-digit AWS account ID owning the domain |
   | `CODEARTIFACT_REPOSITORY` | Maven repository name |

   No AWS access key, secret key, or CodeArtifact token belongs in GitHub settings. The workflow requests a short-lived OIDC token, obtains temporary AWS credentials through the AWS CLI, and requests a CodeArtifact token scoped to the role session (`--duration-seconds 0`) only during release.

## Publish and verify

Merge a reviewed, passing revision to `master`. In GitHub Actions, manually run **Publish core to CodeArtifact** from `master`. The workflow reads the semantic release version from the POM, checks the repository and branch, verifies the exact checkout and quality gates, refuses to publish when required variables are empty or that version already exists, and serializes its own release runs. It deploys the JAR, POM, sources JAR, and Javadoc JAR through Maven, then resolves and executes the published library in a fresh Maven consumer. Do not grant another publisher permission to replace this version; the preflight check cannot prevent a separate principal from racing the workflow.

If deployment succeeds but consumer verification fails, the version may already be published. Diagnose and rerun the consumer check against that repository; do not republish the same version. The [consumer instructions](../README.md#build) describe the settings and commands.

An AWS administrator can verify the version and assets after the workflow succeeds:

```sh
aws codeartifact describe-package-version \
  --domain "$CODEARTIFACT_DOMAIN" \
  --domain-owner "$CODEARTIFACT_DOMAIN_OWNER" \
  --repository "$CODEARTIFACT_REPOSITORY" \
  --format maven --namespace org.c3cavite \
  --package session-manager-core --package-version 1.0.0

aws codeartifact list-package-version-assets \
  --domain "$CODEARTIFACT_DOMAIN" \
  --domain-owner "$CODEARTIFACT_DOMAIN_OWNER" \
  --repository "$CODEARTIFACT_REPOSITORY" \
  --format maven --namespace org.c3cavite \
  --package session-manager-core --package-version 1.0.0
```

Then resolve the dependency from a separate Maven consumer configured for the repository. Archive the source monorepo only after that release validation and the consuming service's migration are complete.
