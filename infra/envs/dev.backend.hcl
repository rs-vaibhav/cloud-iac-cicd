resource_group_name  = "rg-tfstate"
storage_account_name = "sttfstatenotes001" # created by infra/bootstrap - change to your own unique name
container_name       = "tfstate"
key                  = "notes/dev.tfstate"
use_azuread_auth     = true
