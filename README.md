# Jenkins, K8s and Ansible

## This repository is responsible for creating an image that is already set up for a CI/CD pipeline with jenkins.

## Prerequisites

- Farmiliarity with Ansible 
- Farmiliarity with Packer
- You have a domain that is configure through route 53 in AWS

If this is not the case, please headover to a repo and writeup I did on these two tools. It can be found here [Configuration and Change Managemt](https://github.com/mirr254/change-management). On that repo, I talk about how to install and work with this tools.  

This repo will concentrate more on the k8s and jenkins. Under the `ansible` directory, we have roles which are responsible for installation and configuration of different packages that are needed for our pipeline to be complete.

## roles
### aws
- sets up aws authentications through the provided environment variables. Also sets necessary permisions for each of the files created.
### docker
- install docker and docker-compose which will be used in the pipeline
### jenkins service
- install jenkins server and start jenkins services
### k8s
- install `kubectl` and `kops`. Head over to [cloud academy](https://cloudacademy.com/blog/kubernetes-operations-with-kops/) to know more about kops. In brief, Kops is an official Kubernetes project for managing production-grade Kubernetes clusters. Kops is currently the best tool to deploy Kubernetes clusters to Amazon Web Services. The project describes itself as kubectl for clusters.
### nginx
- set up nginx as our reverse proxy. Since jenkins accepts connections in port 8080 we proxy that and accept connections from port 80
### setup
- install libraries needed for other services like jenkins to run. e.g java and python
### supervisor
- a service that runs the `k8s-setup.sh` file responsible to create our k8s clusters

## Instructions

To create an image, 
- clone the repo and checkout to `develop` branch
- cd to root of the project
- create and .env file in root of the project with contents as shown below.

```
#!/bin/bash

export KOPS_CLUSTER_NAME='shammir.tk'
export BUCKET_NAME='shammir.tk'
export KOPS_STATE_STORE=s3://$BUCKET_NAME
export ZONE='us-east-1a'
export AWS_DEFAULT_REGION='us-east-1'
export AWS_ACCESS_KEY_ID='AKIAIdsGLJ2JS'
export AWS_SECRET_ACCESS_KEY='e3qgKWdRWfK1P9px9J80run1Nup'
export KUBECONFIG=~/.kube/$KOPS_CLUSTER_NAME
#
export AWS_USER_GROUP='admins'
export AWS_USER='user'
export AWS_KEY_NAME='kungu_key_pair'

```

`NOTE` group and user MUST not much the ones you have on AWS. This will prevent your details being deleted after the cluster is installed.

- run `packer build packer/base-image.json` to build the image.
- Once it's complete, login to AWS and go to AMI and launch an instance based on your image.
- Remeber to set the inbound rules for `http` port 80
- Note or copy the instance IP and go to AWS route 53 and create an A record for your server. The server name must match the server name in the `nginx` role. So you may want to adjust that to your own.
example of the A records
```
jenkins.shammir.tk A 290.64.89.9
```

- `SSH` into the instance and run the following commands
- `source .env `
- `./k8s-setup.sh` this will set up a cluster on AWS, configure and validate it
- `cat /var/lib/jenkins/secrets/initialAdminPassword` to get the jenkins admin password
- Visit your URL and enjoy your newly created jenkins server

