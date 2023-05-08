resource "google_pubsub_topic" "scale" {
  project = data.google_project.project.project_id
  name = "gke-scale"
  depends_on = [
    google_project_service.pubsub
  ]
}

# resource "google_pubsub_topic" "scaledown" {
#   name = "gke-scaledown"
# }

resource "google_service_account" "function_sa" {
  project = data.google_project.project.project_id
  account_id   = "scale-function"
  display_name = "sa for scale gke"
}

data "google_project" "project" {
    project_id = var.project-id
}

resource "google_project_iam_member" "project" {
  project = data.google_project.project.project_id
  role    = "roles/container.clusterAdmin"
  member  = "serviceAccount:${google_service_account.function_sa.email}"
}



resource "google_cloudfunctions_function" "function" {
  name        = "setSizePubSub"
  description = "Set GKE nodepool size"
  runtime     = "nodejs12"
  region      = var.region
  project = data.google_project.project.project_id

  available_memory_mb   = 128
  source_archive_bucket = google_storage_bucket.scale_bucket.name
  source_archive_object = google_storage_bucket_object.scale_archive.name
  event_trigger         {
    event_type = "providers/cloud.pubsub/eventTypes/topic.publish"
    resource   = "${google_pubsub_topic.scale.name}"
  }
  entry_point           = "setSizePubSub"
  ingress_settings      = "ALLOW_INTERNAL_AND_GCLB"
  service_account_email = google_service_account.function_sa.email
  depends_on = [
    google_project_service.function,
    google_project_service.artifact,
    google_project_service.build,
    google_project_service.eventarc,
    google_project_service.runadmin,
    google_storage_bucket_object.scale_archive
  ]
}

resource "google_storage_bucket" "scale_bucket" {
  name     = "liaurora-scale"
  location = "US"
  project = data.google_project.project.project_id
}

data "archive_file" "nodejs" {
  type        = "zip"
  source_dir = "../scale_nodejs/"
  output_path = "${path.module}/scale.zip"
}

resource "google_storage_bucket_object" "scale_archive" {
  name   = "scale.zip"
  bucket = google_storage_bucket.scale_bucket.name
  source = "scale.zip"
}


resource "google_project_service" "function" {
  service = "cloudfunctions.googleapis.com"
  project = data.google_project.project.project_id
  timeouts {
    create = "30m"
    update = "40m"
  }

  disable_dependent_services = false
}

resource "google_project_service" "artifact" {
  service = "artifactregistry.googleapis.com"
  project = data.google_project.project.project_id
  timeouts {
    create = "30m"
    update = "40m"
  }

  disable_dependent_services = false
}

resource "google_project_service" "build" {
  service = "cloudbuild.googleapis.com"
  project = data.google_project.project.project_id
  timeouts {
    create = "30m"
    update = "40m"
  }

  disable_dependent_services = false
}

resource "google_project_service" "eventarc" {
  service = "eventarc.googleapis.com"
  project = data.google_project.project.project_id
  timeouts {
    create = "30m"
    update = "40m"
  }

  disable_dependent_services = false
}

resource "google_project_service" "runadmin" {
  service = "run.googleapis.com"
  project = data.google_project.project.project_id
  timeouts {
    create = "30m"
    update = "40m"
  }

  disable_dependent_services = false
}


resource "google_project_service" "pubsub" {
  service = "pubsub.googleapis.com"
  project = data.google_project.project.project_id
  timeouts {
    create = "30m"
    update = "40m"
  }

  disable_dependent_services = true
}


resource "google_cloud_scheduler_job" "scaleup_job" {
  project = data.google_project.project.project_id
  region        = var.region
  name        = "scaleup-job"
  description = "scale up job"
  schedule    = "0 8 * * 1-5"
  time_zone   = "America/Toronto"
  pubsub_target {
    # topic.id is the topic's full resource name.
    topic_name = google_pubsub_topic.scale.id
    data       = base64encode("{\"zone\":\"${var.gke-zone}\",\"size\":\"${var.up-size}\",\"pool\":\"${var.gke-pool}\",\"cluster\":\"${var.gke-name}\"}")
  }
  depends_on = [
    google_project_service.scheduler
  ]
}

resource "google_cloud_scheduler_job" "scaledown_job" {
  project = data.google_project.project.project_id
  region        = var.region
  name        = "scaledown-job"
  description = "scale down job"
  schedule    = "0 20 * * 1-5"
  time_zone   = "America/Toronto"

  pubsub_target {
    # topic.id is the topic's full resource name.
    topic_name = google_pubsub_topic.scale.id
    data       = base64encode("{\"zone\":\"${var.gke-zone}\",\"size\":\"${var.down-size}\",\"pool\":\"${var.gke-pool}\",\"cluster\":\"${var.gke-name}\"}")
  }
  depends_on = [
    google_project_service.scheduler
  ]
}

resource "google_project_service" "scheduler" {
  service = "cloudscheduler.googleapis.com"
  project = data.google_project.project.project_id
  timeouts {
    create = "30m"
    update = "40m"
  }

  disable_dependent_services = false
}


resource "google_project_iam_member" "build" {
  project = data.google_project.project.project_id
  role    = "roles/cloudfunctions.developer"
  member  = "serviceAccount:${data.google_project.project.number}@cloudbuild.gserviceaccount.com"
}