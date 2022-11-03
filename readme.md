
﻿# Getting Started with aws-sso-steampipe-tool


**What does this do?**

This tool generate profiles in your ~/.aws/config path based on your level of access in AWS IAM Identity Center in a headless manner and also auto-generates the connections required for [Steampipe](https://steampipe.io/) to connect to one or many accounts using the [AWS](https://hub.steampipe.io/plugins/turbot/aws) plugin. 

**Not Using AWS IAM Identity Center?**

That's okay, the tool supports IAM User w/role chaining as well. Ensure the IAM User or IAM Role utilizing this tool has Read permissions to query AWS Organizations to parse account number and account name. 

**What if I have multiple AWS accounts?**

This tool has great success scaling to thousands of AWS accounts across multiple AWS Organizations.

**How do I run this?**

First make sure you have the following installed:
 - [AWS CLI v2](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html)
 - [Steampipe](https://steampipe.io/downloads)
 - Ensure your AWS Org has [AWS IAM Identity Center](https://aws.amazon.com/iam/identity-center/) setup

git clone https://github.com/somoore/aws-sso-steampipe-tool.git  & open 'sync.sh' in your favorite editor and edit the following:

#Add your AWS IAM Identity Center Start URL & Region on lines 26 & 27:
 

     ### User Defined Variables ###
    START_URL="https://start-url.awsapps.com/start#/";
    REGION="us-east-1";  

Now run

    sh sync.sh sso 

**Note** 
You will be prompted to copy/paste a link to authenticate to AWS SSO. 
Once this is complete, return to the terminal window and press [enter] to retrieve the token and run the rest of the tool. 

**IAM User w/Role Chaining**
Ensure you update line 37 with whatever IAM Role your IAM User assumes cross account. The tool will then query all AWS accounts in the AWS Organization and pass in the IAM Role along with account number to form the ARN path for each ~/.aws/config [profile]. 

    ROLE_NAME="secops_audit_role_example"
    
Then run

    sh sync.sh org
