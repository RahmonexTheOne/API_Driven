#!/bin/bash

# Chemins et Configuration
VENV_BIN="./.venv/bin"
AWS_CMD="$VENV_BIN/awslocal"
export PATH="$PWD/.venv/bin:$PATH"

echo "Démarrage du déploiement (Mode: No-Localhost)..."

# Vérification des outils
if [ ! -f "$AWS_CMD" ]; then
    echo "Erreur : Environnement non détecté. Lancez 'make install' d'abord."
    exit 1
fi

# 1. EC2
echo "Provisionning Instance EC2..."
INSTANCE_ID=$($AWS_CMD ec2 run-instances \
    --image-id ami-df5de72b \
    --count 1 \
    --instance-type t2.micro \
    --query 'Instances[0].InstanceId' \
    --output text)
echo "Instance prête : $INSTANCE_ID"

# 2. Lambda
echo "Packaging de la Lambda..."
rm -f function.zip
zip function.zip lambda_function.py > /dev/null

echo "Déploiement de la logique Serverless (Lambda)..."
$AWS_CMD lambda delete-function --function-name ControlEC2 > /dev/null 2>&1
$AWS_CMD lambda create-function \
    --function-name ControlEC2 \
    --zip-file fileb://function.zip \
    --handler lambda_function.lambda_handler \
    --runtime python3.9 \
    --role arn:aws:iam::000000000000:role/lambda-role > /dev/null

LAMBDA_ARN=$($AWS_CMD lambda get-function --function-name ControlEC2 --query 'Configuration.FunctionArn' --output text)

# 3. API Gateway
echo "Configuration de l'API Gateway..."
API_ID=$($AWS_CMD apigateway create-rest-api --name "EC2ControllerAPI" --query 'id' --output text)
PARENT_ID=$($AWS_CMD apigateway get-resources --rest-api-id $API_ID --query 'items[0].id' --output text)

RESOURCE_ID=$($AWS_CMD apigateway create-resource \
    --rest-api-id $API_ID \
    --parent-id $PARENT_ID \
    --path-part manage \
    --query 'id' --output text)

$AWS_CMD apigateway put-method --rest-api-id $API_ID --resource-id $RESOURCE_ID --http-method POST --authorization-type "NONE" > /dev/null

$AWS_CMD apigateway put-integration \
    --rest-api-id $API_ID \
    --resource-id $RESOURCE_ID \
    --http-method POST \
    --type AWS_PROXY \
    --integration-http-method POST \
    --uri arn:aws:apigateway:us-east-1:lambda:path/2015-03-31/functions/$LAMBDA_ARN/invocations > /dev/null

$AWS_CMD apigateway create-deployment --rest-api-id $API_ID --stage-name dev > /dev/null

# --- DETECTION DYNAMIQUE DE L'URL (FINI LE LOCALHOST) ---
if [ -n "$CODESPACE_NAME" ]; then
    # Nous sommes dans GitHub Codespaces
    HOST_URL="https://${CODESPACE_NAME}-4566.${GITHUB_CODESPACES_PORT_FORWARDING_DOMAIN}"
else
    # Fallback générique si hors codespaces
    HOST_URL="http://127.0.0.1:4566"
fi

FINAL_URL="${HOST_URL}/restapis/$API_ID/dev/_user_request_/manage"
HEALTH_URL="${HOST_URL}/_localstack/health"

echo "--------------------------------------------------"
echo "ARCHITECTURE DÉPLOYÉE (Zero-Localhost Dependency)"
echo "Instance ID : $INSTANCE_ID"
echo "Endpoint Public : $FINAL_URL"
echo "Health Check : $HEALTH_URL"
echo "--------------------------------------------------"
echo "Commande de test :"
echo "curl -X POST -H 'Content-Type: application/json' -d '{\"action\": \"stop\", \"instance_id\": \"$INSTANCE_ID\"}' $FINAL_URL"
echo "Santé LocalStack :"
echo "   curl $HEALTH_URL"