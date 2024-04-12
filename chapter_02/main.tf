terraform {
  required_version = "~>1.7"
  required_providers {
    local = {
      source = "hashicorp/local"
      version = "~>2.5"
    }
  }
}

resource "local_file" "literature" {
  filename = "art_of_war.txt"
  content = <<-EOT
    Sun Tzu said: The art of war is of vital importance to the State.

    It is a matter of life and death, a road either to safety or to ruin. Hence it is a subject of inquiry which can on no account be neglected.
  EOT
}
