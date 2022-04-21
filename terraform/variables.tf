variable "region" {
  default = "us-west1"
}
variable "gke-zone" {
  default = "us-west1-a"
}
variable "gke-pool" {
  default = "default"
}
variable "up-size" {
  default = 3
}
variable "down-size" {
  default = 0
}
variable "gke-name" {
    default = "cluster-1"
}