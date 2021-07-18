# Securing connections to Cloud Run using Apigee X
This section will look at securing connections to cloud run using Apigee X by focussing on following 
* Service accounts will only be provisioned in Apigee X to avoid service account leakage issue
* Create private network connectivty from Apigee to Cloud Run

There are a few options that we will explore for this

## Option 1 - With Envoy Proxy on GCE
In this option we will look at creating an envoy proxy on Google Compute Engine and using envoy to rewrite the Host header to route requests to Cloud Run. This option will use [Private Google Access](https://cloud.google.com/vpc/docs/private-google-access) option.
Step are
1. Create 1 or more VM without any external IP and with PGA enabled
2. Install envoy on VMs and use `envoy.yaml` file from this project as configuration for envoy
3. In your Apigee proxy or client application set the `x-set-host` header to point to cloud run url which will look like `randomname.a.run.app`

## Option 2 - With Envoy Proxy on [GKE Autopilot](https://cloud.google.com/kubernetes-engine/docs/concepts/autopilot-overview)
In this option we will create a [private kubernetes cluster](https://cloud.google.com/kubernetes-engine/docs/concepts/private-cluster-concept) and with envoy deployed to do URL re-write to point to Cloud Run
### Create a GKE autopilot cluster with private nodes enabled.
This will automatically enable Private Google Access for nodes
```
gcloud container clusters create-auto "envoy-autopilot-cluster" \
  --project $PROJECT \
  --region $REGION \
  --release-channel "regular" \
  --network default \
  --subnetwork default \
  --cluster-ipv4-cidr "/21" \
  --services-ipv4-cidr "/27" \
  --enable-private-nodes \
  --no-enable-master-authorized-networks 
```
We are using above options to allow kubectl running from outside the provate network to connect to the cluster. If there is a private network to cluster (e.g. using an interconnect) or you are using cloud VM to kubectl then ensure following options are enabled
* `--enable-private-nodes` create a private cluster with no external IP addresses.
* `--enable-master-authorized-networks`* specifies that access to the public endpoint is restricted to IP address ranges that you authorize
* `--enable-private-endpoint` indicates that the cluster is managed using the private IP address of the control plane API endpoint

Enabling these provides the highest level of restricted access as described here.

***Remember it will take time for cluster to be created***

### Build and deploy the envoy container

1. Execute following command from within this directory to build and store container image on google cloud
```gcloud builds submit --tag gcr.io/$PROJECT/envoyd```
2. Deploy container image into your cluster
```kubectl apply -f deploy_envoy.yaml```
3. Create an internal load balancer service
```kubectl apply -f create_service.yaml```
4. Get the internal IP assigned to load balancer
```kubectl get service ilb-service```
External IP from output of this command will be the internal IP for envoy cluster


## Option 3: Use iptable routing
In this option we will create a group of VMs with iptable configuration to route traffic coming from Apigee to Cloud Run. Host header rewrite will need to be done by Apigee in this option. Additionally this option will use [Private Service Connect](https://cloud.google.com/vpc/docs/private-service-connect) option to ensure traffic is routed internally to Cloud Run.

### Create Private Service Connect 
Private Service Connect endpoints are registered with Service Directory which is a platform to store, manage and publish services. When you create a PSC endpoint to access google apis and services, you select a service directory region. Service Directory is a regional service. When you create a PSC endpoint, following DNS confgurations are created
* a service directory private dns zone for p.googleapis.com
* DNS records for each service made available using that endpoint

#### Create a PSC endpoint
Reserve a global internal IP address to assign to the endpoint. e.g. 10.99.0.2 should work for most demo projects
```
gcloud compute addresses create private-service-connect-ip \                                      
  --global \
  --purpose=PRIVATE_SERVICE_CONNECT \
  --addresses=10.99.0.2 \
  --network=default
```
#### Create a forwarding rule to connect the endpoint to Google APIs and services
```
gcloud compute forwarding-rules create allapiendpoint \
  --global \
  --network=default \
  --address=private-service-connect-ip \
  --service-directory-registration=projects/$PROJECT/locations/$REGION \
  --target-google-apis-bundle=all-apis
```
You can control the use of PSC endpoints by specifying different 
```
target-google-apis-bundle
``` 

Verfiy that the endpoint is working
```
curl -v 10.99.0.2/generate_204
```

List the endpoints
```
gcloud compute forwarding-rules list --filter target="all-apis" --global
```

Get endpoint info
```
gcloud compute forwarding-rules describe allapiendpoint --global
```

Create a private DNS zone for cloud run APIs
```
gcloud beta dns managed-zones create psc-endpoint \
    --dns-name="run.app." \
    --visibility="private" \
    --networks="default"
```

Add an A record that will point to private IP
```
*.run.app   A   300 *   10.99.0.2
```

Create DNS peering 
```
gcloud beta services peered-dns-domains create cloudrun-domain --network=default --dns-suffix=run.app.
```

Now in Apigee proxy 
* Ensure that you are setting the Host header using AssignMessage policy to cloud run url
* Ensure that a.run.app is the target server or target url

### Create routing VM group
Create one or more VMs and ensure to provide following options
```
export APIGEE_ENDPOINT=10.99.0.2
--metadata ENDPOINT="$APIGEE_ENDPOINT",startup-script-url=gs://apigee-5g-saas/apigee-envoy-proxy-release/latest/conf/startup-script.sh```

### Configure Apigee proxy
Set target server or target url to point to VM. VM will ensure all traffic is routed to PSC which will ensure that traffic is routed to cloud run application based on host header.
For now add following to your apigee proxy `HTTPTargetConnection`
```
        <SSLInfo>
            <Enabled>true</Enabled>
            <IgnoreValidationErrors>true</IgnoreValidationErrors>
        </SSLInfo>
```