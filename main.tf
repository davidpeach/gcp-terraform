terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "4.74.0"
    }
    github = {
      source  = "integrations/github"
      version = "~> 4.0"
    }
  }
}

provider "google" {
  credentials = file("./test1-393310-061d20257d33.json")
  project     = "test1-393310"
  region      = "europe-west2"
  zone        = "europe-west2-b"
}

provider "github" {
  token = ""
}

resource "google_compute_network" "vpc_network" {
  name = "peach-test-network"
}

resource "google_service_account" "github-deployer" {
  account_id   = "github-deployer"
  display_name = "Github Deployer"
}

resource "google_project_iam_member" "kubernetes_cluster_admin" {
  project = "test1-393310"
  role    = "roles/container.clusterAdmin"
  member  = "serviceAccount:${google_service_account.github-deployer.email}"
}

resource "google_service_account_key" "github-deployer-key" {
  service_account_id = google_service_account.github-deployer.name
  public_key_type    = "TYPE_X509_PEM_FILE"
}

resource "github_actions_secret" "gcp-access-key" {
    repository       = "gcp-test"
    secret_name      = "GCP_ACCESS_KEY"
    plaintext_value  = "${google_service_account_key.github-deployer-key.public_key}"
}

resource "google_container_cluster" "primary" {
  name     = "peach-gke-cluster"
  location = "europe-west2-b"

  # We can't create a cluster with no node pool defined, but we want to only use
  # separately managed node pools. So we create the smallest possible default
  # node pool and immediately delete it.
  remove_default_node_pool = true
  initial_node_count       = 1
}

resource "google_container_node_pool" "primary_preemptible_nodes" {
  name       = "peach-node-pool"
  location   = "europe-west2-b"
  cluster    = google_container_cluster.primary.name
  node_count = 1

  node_config {
    preemptible  = true
    machine_type = "e2-medium"

    # Google recommends custom service accounts that have cloud-platform scope and permissions granted via IAM Roles.
    service_account = google_service_account.github-deployer.email
    oauth_scopes    = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]
  }
}
