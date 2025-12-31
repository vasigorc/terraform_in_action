terraform {
  required_version = "~>1.12.0"
  required_providers {
    random = {
      source  = "hashicorp/random"
      version = "~>3.7"
    }
  }
}

variable "words" {
  description = "A word pool to use for Mad libs"
  type = object({
    nouns      = list(string),
    adjectives = list(string),
    verbs      = list(string),
    adverbs    = list(string),
    numbers    = list(number),
  })

  validation {
    condition     = length(var.words["nouns"]) >= 10
    error_message = "At least 10 nouns must be supplied"
  }
}

variable "num_files" {
  type    = number
  default = 100
}

locals {
  uppercase_words = { for k, v in var.words : k => [for s in v : upper(s)] }
  templates       = tolist(fileset(path.module, "templates/*.txt"))
}

resource "random_shuffle" "random_nouns" {
  count = var.num_files
  input = local.uppercase_words["nouns"]
}

resource "random_shuffle" "random_adjectives" {
  count = var.num_files
  input = local.uppercase_words["adjectives"]
}

resource "random_shuffle" "random_verbs" {
  count = var.num_files
  input = local.uppercase_words["verbs"]
}

resource "random_shuffle" "random_adverbs" {
  count = var.num_files
  input = local.uppercase_words["adverbs"]
}

resource "random_shuffle" "random_numbers" {
  count = var.num_files
  input = local.uppercase_words["numbers"]
}

resource "local_file" "mad_libs" {
  count    = var.num_files
  filename = "madlibs/madlibs-${count.index}.txt"
  content = templatefile(element(local.templates, count.index),
    {
      nouns      = random_shuffle.random_nouns[count.index].result
      adjectives = random_shuffle.random_adjectives[count.index].result
      verbs      = random_shuffle.random_verbs[count.index].result
      adverbs    = random_shuffle.random_adverbs[count.index].result
      numbers    = random_shuffle.random_numbers[count.index].result
  })
}

data "archive_file" "mad_libs" {
  // archive_file must be evaluated after all the Mad Libs paragraph have been created
  depends_on  = [local_file.mad_libs]
  source_dir  = "${path.module}/madlibs"
  output_path = "${path.cwd}/madlibs.zip"
  type        = "zip"
}
