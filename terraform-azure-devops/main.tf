provider "azuredevops" {
  version               = ">= 0.0.1"
  org_service_url       = var.orgurl
  personal_access_token = var.pat
}

resource "azuredevops_project" "project" {
  project_name       = "Terraform DevOps Project"
  description        = "Sample project to demonstrate AzDevOps <-> Terraform integragtion"
  visibility         = "private"
  version_control    = "Git"
  work_item_template = "Agile"
}

resource "azuredevops_git_repository" "repo" {
  project_id = azuredevops_project.project.id
  name       = "Sample Empty Git Repository"

  initialization {
    init_type = "Clean"
  }
}

resource "azuredevops_build_definition" "build" {
  project_id = azuredevops_project.project.id
  name       = "Sample Build Pipeline"

  ci_trigger {
    use_yaml = true
  }

  repository {
    repo_type   = "TfsGit"
    repo_id     = azuredevops_git_repository.repo.id
    branch_name = azuredevops_git_repository.repo.default_branch
    yml_path    = "azure-pipeline.yaml"
  }

  variable {
    name      = "mypipelinevar"
    value     = "Hello From Az DevOps Pipeline!"
    is_secret = false
  }
}



### DEMO with var groups

resource "azuredevops_variable_group" "vars" {
  project_id   = azuredevops_project.project.id
  name         = "my-variable-group"
  allow_access = true

  variable {
    name  = "var1"
    value = "value1"
  }

  variable {
    name  = "var2"
    value = "value2"
  }
}

resource "azuredevops_build_definition" "buildwithgroup" {
  project_id = azuredevops_project.project.id
  name       = "Sample Build Pipeline with VarGroup"

  ci_trigger {
    use_yaml = true
  }

  variable_groups = [
    azuredevops_variable_group.vars.id
  ]

  repository {
    repo_type   = "TfsGit"
    repo_id     = azuredevops_git_repository.repo.id
    branch_name = azuredevops_git_repository.repo.default_branch
    yml_path    = "azure-pipeline-with-vargroup.yaml"
  }

}

### DEMO with var groups AND KEYVAULT!

data "azurerm_client_config" "current" {
}

provider "azurerm" {
  version = "~> 2.6.0"
  features {
    key_vault {
      purge_soft_delete_on_destroy = true
    }
  }
}

## Service Principal for DevOps

resource "azuread_application" "azdevopssp" {
  name = "azdevopsterraform"
}

resource "random_string" "password" {
  length  = 32
  special = true
}

resource "azuread_service_principal" "azdevopssp" {
  application_id = azuread_application.azdevopssp.application_id
}

resource "azuread_service_principal_password" "azdevopssp" {
  service_principal_id = azuread_service_principal.azdevopssp.id
  value                = random_string.password.result
  end_date             = "2024-01-01T00:00:00Z"
}

resource "azurerm_role_assignment" "main" {
  principal_id         = azuread_service_principal.azdevopssp.id
  scope                = "/subscriptions/${data.azurerm_client_config.current.subscription_id}"
  role_definition_name = "Contributor"
}

## KeyVault

resource "azurerm_resource_group" "rg" {
  name     = "myazdevops-rg"
  location = "westeurope"
}

resource "azurerm_key_vault" "keyvault" {
  name                        = "myazdevopskv"
  location                    = "westeurope"
  resource_group_name         = azurerm_resource_group.rg.name
  enabled_for_disk_encryption = true
  tenant_id                   = data.azurerm_client_config.current.tenant_id
  soft_delete_enabled         = true
  purge_protection_enabled    = false

  sku_name = "standard"

  access_policy {
    tenant_id = data.azurerm_client_config.current.tenant_id
    object_id = data.azurerm_client_config.current.object_id

    secret_permissions = [
      "backup",
      "get",
      "list",
      "purge",
      "recover",
      "restore",
      "set",
      "delete",
    ]
    certificate_permissions = [
    ]
    key_permissions = [
    ]
  }

}

## Grant DevOps SP permissions

resource "azurerm_key_vault_access_policy" "azdevopssp" {
  key_vault_id = azurerm_key_vault.keyvault.id

  tenant_id = data.azurerm_client_config.current.tenant_id
  object_id = azuread_service_principal.azdevopssp.object_id

  secret_permissions = [
    "get",
    "list",
  ]
}

## Create a secret

resource "azurerm_key_vault_secret" "mysecret" {
  key_vault_id = azurerm_key_vault.keyvault.id
  name         = "kmysupersecretsecret"
  value        = "KeyVault for the Win!"
}


## Service Connection

resource "azuredevops_serviceendpoint_azurerm" "endpointazure" {
  project_id            = azuredevops_project.project.id
  service_endpoint_name = "AzureRMConnection"
  credentials {
    serviceprincipalid  = azuread_service_principal.azdevopssp.application_id
    serviceprincipalkey = random_string.password.result
  }
  azurerm_spn_tenantid      = data.azurerm_client_config.current.tenant_id
  azurerm_subscription_id   = data.azurerm_client_config.current.subscription_id
  azurerm_subscription_name = "<SUBSCRIPTION_NAME>"
}

## Grant permission to use service connection

resource "azuredevops_resource_authorization" "auth" {
  project_id  = azuredevops_project.project.id
  resource_id = azuredevops_serviceendpoint_azurerm.endpointazure.id
  authorized  = true
}

## Pipeline with access to kv secret

resource "azuredevops_variable_group" "kyintegratedvargroup" {
  project_id   = azuredevops_project.project.id
  name         = "kyintegratedvargroup"
  description  = "KeyVault integrated Variable Group"
  allow_access = true

  key_vault {
    name                = azurerm_key_vault.keyvault.name
    service_endpoint_id = azuredevops_serviceendpoint_azurerm.endpointazure.id
  }

  variable {
    name    = "kmysupersecretsecret"
  }
}

resource "azuredevops_build_definition" "buildwithkeyvault" {
  project_id = azuredevops_project.project.id
  name       = "Sample Build Pipeline with KeyVault Integration"

  ci_trigger {
    use_yaml = true
  }

  variable_groups = [
    azuredevops_variable_group.kyintegratedvargroup.id
  ]

  repository {
    repo_type   = "TfsGit"
    repo_id     = azuredevops_git_repository.repo.id
    branch_name = azuredevops_git_repository.repo.default_branch
    yml_path    = "azure-pipeline-with-keyvault.yaml"
  }

}
