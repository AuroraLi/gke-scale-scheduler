# Scheduled GKE scaling

This is based on GCP offical guide [Scheduling compute instances with Cloud Scheduler](https://cloud.google.com/scheduler/docs/start-and-stop-compute-engine-instances-on-a-schedule).

## Steps
Login to GCP and set project (same as where your GKE cluster is).
```
gcloud auth login
export PROJECT_ID=<your project ID>
gcloud config set project $PROJECT_ID
```

Go to `terraform` folder.
```
cd terraform
```

Modify `terraform.tfvars` file to reflect your environment.

Example:
```
gke-zone="us-west1-a"
gke-pool="default"
up-size=3
down-size=0
region="us-west1" #Should be in the same region as your cluster
gke-name="cluster-1"
```

Apply Terraform:
```
terraform plan -out tfplan
terraform apply "tfplan"
```

You should see 1 Service Account, 2 Cloud Scheduler jobs, 1 Pub/Sub topic, 1 Pub/Sub subscription, and 1 Cloud Function deployed. 

Please fully test in your dev environment. This is not intended to be used in prod. 

## Update NodeJS function - WIP
Modify `index.js` and `package.json` files as needed. Zip them to `/terraform` folder
```
cd terraform
zip scale.zip ../scale_nodejs/index.js ../scale_nodejs/package.json
```

Apply the changes:
```
terraform plan -out tfplan
terraform apply "tfplan"
```