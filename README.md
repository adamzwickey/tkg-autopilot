# tkg-autopilot
This project is meant to automate the paving of TKG enfirments, including common extensions, in AWS.  It utilizes TKG, Helm, and ArgoCD utilizing the [App of Apps pattern](https://argoproj.github.io/argo-cd/operator-manual/cluster-bootstrapping/)


![home](https://gitlab.com/azwickey/tkg-autopilot/-/raw/master/img/argo.png "argo")

## Installation

- Fork this repo.  Since this is your GitOps source of truth, you must fork rather than simply clone
- Make a copy of vars.yaml.example named vars.yaml in the root directory of your repo. 
- Edit vars.yaml, providing configuration values that reflect your desired envornment.
- Copy the vars.yaml file to the root of the S3 bucket you specfied in `aws.bucket`.  Additionally, make sure that the S3 bucket has an access policy that allows your IAM instance profile R/W access.  For example:
```bash
aws s3 cp vars.yaml s3://tkg-autopilot/vars.yaml
```
- Additionally, edit the values.yaml file(s) in `/cd/argo/mgmt`, `/cd/argo/workload1`, and `/cd/argo/workload2` to reflect your environment.  This will drive the true GitOps worklfow.  And value that has a comment of `# This must be overridden ` does not need to be changed as this is a _Secret_ that will be read from the params.yaml that is uploaded to the S3 bucket.
- When you are ready to deploy execute the install script:
```bash
source ./scripts/install.sh
```
This will execute the following tasks:

- Create an EC2 launch template.  The details of the templace are stored in `lt.yaml`
- Launch an instance using this template, named TKG Bootstrapper.
- Tails the output of the bootstrapping log, which is found in `/var/log/cloud-init-output.log` on the instance.
