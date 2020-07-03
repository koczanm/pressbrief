#!/usr/bin/env bash

export AWS_DEFAULT_OUTPUT="text"

echo "Checking if all parameters are set ..."

if [[ -z "${AWS_ACCESS_KEY_ID}" ]]; then

    echo "AWS_ACCESS_KEY_ID not found!"
    exit 1

fi

if [[ -z "${AWS_SECRET_ACCESS_KEY}" ]]; then

    echo "AWS_SECRET_ACCESS_KEY not found!"
    exit 1

fi

if [[ -z "${AWS_DEFAULT_REGION}" ]]; then

    echo "AWS_DEFAULT_REGION not found!"
    exit 1

fi

if [[ -z "${DROPBOX_ACCESS_TOKEN}" ]]; then

    echo "DROPBOX_ACCESS_TOKEN not found!"
    exit 1

fi

echo "Checking if stack exists ..."

aws cloudformation describe-stacks --stack-name PressbriefStack 1>/dev/null 2>&1
status=$?

if [[ $status -ne 0 ]] ; then

    echo "Stack does not exist, creating ..."

    aws cloudformation create-stack \
        --stack-name PressbriefStack \
        --template-body file://aws-resources.yaml \
        --capabilities CAPABILITY_NAMED_IAM \
        --parameters \
            ParameterKey=ConsumerKey,ParameterValue="${CONSUMER_KEY}" \
            ParameterKey=ConsumerSecret,ParameterValue="${CONSUMER_SECRET}" \
            ParameterKey=DropboxAccessToken,ParameterValue="${DROPBOX_ACCESS_TOKEN}" \
            ParameterKey=TargetUsername,ParameterValue="${TARGET_USERNAME}" 1>/dev/null

    echo "Waiting for stack to be created ..."

    aws cloudformation wait stack-create-complete --stack-name PressbriefStack

else

    echo "Stack exists, attempting update ..."

    set +e
    output=$(aws cloudformation update-stack \
                --stack-name PressbriefStack \
                --template-body file://aws-resources.yaml \
                --capabilities CAPABILITY_NAMED_IAM \
                --parameters \
                    ParameterKey=ConsumerKey,ParameterValue=${CONSUMER_KEY} \
                    ParameterKey=ConsumerSecret,ParameterValue=${CONSUMER_SECRET} \
                    ParameterKey=DropboxAccessToken,ParameterValue=${DROPBOX_ACCESS_TOKEN} \
                    ParameterKey=TargetUsername,ParameterValue=${TARGET_USERNAME} 2>&1)
    status=$?
    set -e

    if [[ $status -ne 0 ]] ; then

        if [[ $output == *"ValidationError"* && $output == *"No updates"* ]] ; then
            
            echo "Creation finished successfully - no updates to be performed"

        else
            exit $status
        fi

    else

        echo "Waiting for stack update to complete ..."
        
        aws cloudformation wait stack-update-complete --stack-name PressbriefStack
    
    fi

fi

echo "Deploying Python function to Lambda ..."

aws lambda update-function-code --function-name Pressbrief --zip-file fileb://function.zip 1>/dev/null

echo "Deployment completed successfully"