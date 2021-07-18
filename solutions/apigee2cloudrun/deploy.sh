#!/bin/bash

set -e

export PROJECT="YOURPROJECTNAME" #Also change this in deploy_envoy.yaml
export REGION="YOURREGIONNAME"
export CLUSTERNAME="envoy-autopilot-cluster"

echo "Create cluster $CLUSTERNAME in region $REGION for project $PROJECT"
gcloud container clusters create-auto $CLUSTERNAME \
  --project $PROJECT \
  --region $REGION \
  --release-channel "regular" \
  --network "projects/$PROJECT/global/networks/default" \
  --subnetwork "projects/$PROJECT/regions/$REGION/subnetworks/default" \
  --cluster-ipv4-cidr "/21" \
  --services-ipv4-cidr "/27" \
  --enable-private-nodes \
  --no-enable-master-authorized-networks 

echo "Creating container image for envoy"
gcloud builds submit --tag gcr.io/$PROJECT/envoyd

echo "Deploying container"
kubectl apply -f deploy_envoy.yaml

# There should be some wait here or a mechanism to know that pods are up and running before service is created
sleep 5m

echo "Creating service"
kubectl apply -f create_service.yaml

sleep 1m

echo "Getting Service IP"
kubectl get service envoy-ilb-service
sleep 1m

# And get the IP
kubectl get service envoy-ilb-service -o jsonpath={$.status.loadBalancer.ingress\[0\].ip}