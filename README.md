# Anya-Final-Project

# Setting up fully robust nodes with monitoring
Note: This is a work in progress. Details on requirements can be found here https://github.com/Joinanya/project/blob/main/project.md

# Description

This repo specifically spins up multiple instances of polkadot nodes specifically collator nodes, boot nodes and rpc nodes. Terraform is used to spin up the infrastructure for the nodes - networking, security etc, while the Ansible is used for configuring the polkadot binary on the nodes, as well as monitoring

## Prerequisites
- Terraform
- AWS CLI configured
- Ansible
- Python 3
- Boto 3 (sudo pip3 install boto3)

## To run the Terraform script:

```
git clone the repository
$cd Terraform

terraform init
terraform plan
terraform apply
```
This spins up the infrastructure on AWS
It also creates an AWS IAM role named `dynamic_inventory_role` that would be assumed when dealing with ansibles dynamic inventory below

## To run the Ansible script:
Ansible was implemmted using dynamic inventories, the first step is to assume the IAM role that has full access to EC2, the role already created with Terraform
`dynamic_inventory_role`
You can verify the role  or you can choose to use the default role attached to the AWS CLI, provided there is EC2FullAccess permission

With that, we can go ahead to run our configurations
```
$cd Ansible
$ansible-playbook playbook.yaml
```

There are 3 plays in the playbook.yaml file, each play for the individual node categories. The plays utilize ansible roles, already preconfigured.
there are ansible roles for configuring polkadot, as well as configuring prometheus, grafana and the node exporters

## To-Do
- Fix RPC nodes TLS and view on polkadot.js.org
- Setup Alerts, Journald
- Use packer to bake dependencies and reduce build time / self hosted runner with cicd
