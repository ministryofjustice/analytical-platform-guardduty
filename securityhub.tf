# Activate Security Hub in Landing account
module "security-hub-landing" {
  source                    = "modules/securityhub"
  assume_role_in_account_id = "${var.ap_accounts["landing"]}"
}

# Activate Security Hub in dev account
module "security-hub-dev" {
  source                    = "modules/securityhub"
  assume_role_in_account_id = "${var.ap_accounts["dev"]}"
}

# Activate Security Hub in prod account
module "security-hub-prod" {
  source                    = "modules/securityhub"
  assume_role_in_account_id = "${var.ap_accounts["prod"]}"
}

# Activate Security Hub in data account
module "security-hub-data" {
  source                    = "modules/securityhub"
  assume_role_in_account_id = "${var.ap_accounts["data"]}"
}
