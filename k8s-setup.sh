#!/usr/bin/env bash

set -o errexit #set -e  #exit immediately if a command  exits with non-zero status
set -o xtrace #set -x #to trace what gets executed. Useful for debugging.

# variavles from environment variables
found_bucket=false
CLUSTER_NAME=$KOPS_CLUSTER_NAME
BUCKET_NAME=$BUCKET_NAME
DNS_ZONE=$AWS_DEFAULT_REGION

checkIfBucketExists() {
    local buckets=$(aws s3api list-buckets --query "Buckets[].Name")
    local bucket="${BUCKET_NAME}"
    if [[ "${buckets[@]}" =~ "${bucket}" ]]; then
        found_bucket=true
        echo "found bucket ${bucket}"
    else
        echo "${bucket} not found"
    fi
}

# Creates the bucket if doesn't exist and/or sets 
# the KOPS_STATE_STORE
createBucket() {
    checkIfBucketExists
    if [ $(echo $found_bucket) == false ]; then
        echo "Creating bucket ${BUCKET_NAME}"
        aws s3 mb s3://$BUCKET_NAME
    fi
    export KOPS_STATE_STORE=s3://$BUCKET_NAME
}

#enable versioning for the above s3 bucket
enableBucketVersioning() {
    aws s3api put-bucket-versioning --bucket $BUCKET_NAME --versioning-configuration Status=Enabled
}

#create a public key to use when SSH'ng
#use the pem file we copied earlier
createPublicKey() {
    echo "Generate public key from pem file"
    chmod 400 /home/ubuntu/aws-ssh.pem
    ssh-keygen -y -f /home/ubuntu/aws-ssh.pem > /home/ubuntu/.ssh/id_rsa.pub
}

createOrUpdateCluster() {
    # Only create a new cluster if one does not exist
    # else update existing cluster
    #specify the locationConstraint to allow creation of clusters in other regions aprt from us-east-1
    kops get clusters --name ${CLUSTER_NAME} > /dev/null 2>&1
    if [ $? == 1 ]; then
        echo "Creating cluster ${CLUSTER_NAME}"
        kops create cluster --cloud aws --zones=us-east-2b \
            --dns-zone ${DNS_ZONE} --master-size t2.micro \
            --node-size t2.micro --name ${CLUSTER_NAME} \
            --ssh-public-key /home/ubuntu/.ssh/${KEY_NAME}.pub \
            --state s3://${BUCKET_NAME} --yes 

        while true; do
            kops validate cluster --name $CLUSTER_NAME \
              --state s3://${BUCKET_NAME} | grep 'is ready' > /dev/null 2>&1;
            if [ $? == 0 ]; then
                break
            else
                echo "cluster ${CLUSTER_NAME} is still provisioning"
            fi
            sleep 30
        done
    else
        echo "Updating cluster ${CLUSTER_NAME}"
        kops update cluster --name ${CLUSTER_NAME}
    fi
}

configureJenkins() {
    # Add jenkins to docker group
    sudo usermod -a -G docker jenkins
    sudo service jenkins restart

    # Enable jenkins to access K8s cluster
    sudo mkdir -p /var/lib/jenkins/.kube
    sudo cp ~/.kube/config /var/lib/jenkins/.kube/
    cd /var/lib/jenkins/.kube/
    sudo chown jenkins:jenkins config
    sudo chmod 750 config
    cd $HOME
}

main() {
    createBucket
    enableBucketVersioning
    createPublicKey
    createOrUpdateCluster
    configureJenkins
}

main "$@"