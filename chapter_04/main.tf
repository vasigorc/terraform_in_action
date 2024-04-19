module "autoscaling" {
  source    = "./modules/autoscaling"
  namespace = var.namespace
  // input variables for the autoscaling modules, set by other module's outputs
  ssh_keypair = var.ssh_keypair

  vpc       = module.networking.vpc
  sg        = module.networking.sg
  db_config = module.database.db_config
}

module "database" {
  source    = "./modules/database"
  namespace = var.namespace

  vpc = module.networking.vpc // data bubbles up from the networking module and trickles down into the db module
  sg  = module.networking.sg
}

module "networking" {
  source    = "./modules/networking"
  namespace = var.namespace
}
