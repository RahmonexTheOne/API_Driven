#!/bin/bash

# Définition stricte des chemins vers nos outils isolés
VENV_BIN="./.venv/bin"
AWS_CMD="$VENV_BIN/awslocal"

# On ajoute le bin du venv au PATH pour que awslocal trouve aws
export PATH="$PWD/.venv/bin:$PATH"

echo "Démarrage du déploiement..."

# Vérification que les outils sont là
if [ ! -f "$AWS_CMD" ]; then
    echo "Erreur : awslocal introuvable. Avez-vous lancé 'make install' ?"
    exit 1
fi

# 1. Création Instance EC2
echo "Lancement EC2..."
INSTANCE_ID=$($AWS_CMD ec2 run-instances \
    --image-id ami-df5de72b \
    --count 1 \
    --instance-type t2.micro \
    --query 'Instances[0].InstanceId' \
    --output text)

if [ -z "$INSTANCE_ID" ] || [ "$INSTANCE_ID" == "None" ]; then
    echo "❌ Erreur lors de la création de l'instance."
    exit 1
fi
echo "Instance créée : $INSTANCE_ID"

# 2. Lambda
echo "Packaging Lambda..."
rm -f function.zip
zip function.zip lambda_function.py > /dev/null

echo "Déploiement Lambda..."
$AWS_CMD lambda delete-function --function-name ControlEC2 > /dev/null 2>&1
$AWS_CMD lambda create-function \
    --function-name ControlEC2 \
    --zip-file fileb://function.zip \
    --handler lambda_function.lambda_handler \
    --runtime python3.9 \
    --role arn:aws:iam::000000000000:role/lambda-role > /dev/null

LAMBDA_ARN=$($AWS_CMD lambda get-function --function-name ControlEC2 --query 'Configuration.FunctionArn' --output text)

# 3. API Gateway
echo "Déploiement API Gateway..."
API_ID=$($AWS_CMD apigateway create-rest-api --name "EC2ControllerAPI" --query 'id' --output text)
PARENT_ID=$($AWS_CMD apigateway get-resources --rest-api-id $API_ID --query 'items[0].id' --output text)

RESOURCE_ID=$($AWS_CMD apigateway create-resource \
    --rest-api-id $API_ID \
    --parent-id $PARENT_ID \
    --path-part manage \
    --query 'id' --output text)

$AWS_CMD apigateway put-method \
    --rest-api-id $API_ID \
    --resource-id $RESOURCE_ID \
    --http-method POST \
    --authorization-type "NONE" > /dev/null

$AWS_CMD apigateway put-integration \
    --rest-api-id $API_ID \
    --resource-id $RESOURCE_ID \
    --http-method POST \
    --type AWS_PROXY \
    --integration-http-method POST \
    --uri arn:aws:apigateway:us-east-1:lambda:path/2015-03-31/functions/$LAMBDA_ARN/invocations > /dev/null

$AWS_CMD apigateway create-deployment --rest-api-id $API_ID --stage-name dev > /dev/null

echo "--------------------------------------------------"
echo "DÉPLOIEMENT RÉUSSI"
echo "Instance ID : $INSTANCE_ID"
echo "URL API : http://localhost:4566/restapis/$API_ID/dev/_user_request_/manage"
echo "--------------------------------------------------"
echo "Testez votre API avec cette commande :"
echo "curl -X POST -H 'Content-Type: application/json' -d '{\"action\": \"stop\", \"instance_id\": \"$INSTANCE_ID\"}' http://localhost:4566/restapis/$API_ID/dev/_user_request_/manage"