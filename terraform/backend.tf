terraform {
  backend "azurerm" {
    # These values are provided via init command or environment variables
    # resource_group_name  = "tfstate-rg"
    # storage_account_name = "tfstate<random>"
    # container_name       = "tfstate"
    # key                  = "fileanalysis.tfstate"
  }
}
