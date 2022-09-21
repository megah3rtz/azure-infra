#export tenant_id="ec71c6d7-f034-46a6-9166-ccbbb6336c32"
#export resource_group_name="terraform-rg"
#export client_id="ac784022-e7c2-44d7-b536-d4ce401e0a91"
#export client_secret="5e.8Q~FqSX2IWspMy1_eGI3xExeFKKikHqDAJc9H"
#export subscription_id="f7e9b3e5-ddde-49b3-a174-5d734241380e"
#export storage_account_name="terraformstate99"
#export container_name="terraformstate"
#export tf_key="base-infra"
#export tf_repo="base-infra"

tenant_id := ${tenant_id}
resource_group_name := ${resource_group_name}
client_id := ${client_id}
client_secret := ${client_secret}
subscription_id := ${subscription_id}
storage_account_name := ${storage_account_name}
container_name := ${container_name}
key := ${tf_key}
repo := ${tf_repo}

# login:
# 	@echo "[-] Logging in to azcli"
# 	@az login --service-principal -u ${client_id} -p ${client_secret} -t ${tenant_id}
# 	@echo "[+] Logged in to azcli"
	
init:
	@echo "[-] Run terraform init"
	terraform -chdir='${repo}' init -backend-config='tenant_id=${tenant_id}' -backend-config='client_id=${client_id}' -backend-config='client_secret=${client_secret}'  -backend-config='subscription_id=${subscription_id}' -backend-config='resource_group_name=${resource_group_name}' -backend-config='subscription_id=${subscription_id}' -backend-config='container_name=${container_name}' -backend-config='key=${key}' -backend-config='storage_account_name=${storage_account_name}'
	@echo "[+] Init complete"

plan: init
	@echo "[-] Run terraform plan"
	@ARM_CLIENT_ID='${client_id}' ARM_CLIENT_SECRET='${client_secret}' ARM_TENANT_ID='${tenant_id}' ARM_SUBSCRIPTION_ID='${subscription_id}' terraform -chdir='${repo}' plan -var-file=tfvars/default.tfvars -out '${repo}.plan'
	@echo "[+] Plan complete"

apply: plan
	@echo "[-] Run terraform apply"
	@ARM_CLIENT_ID='${client_id}' ARM_CLIENT_SECRET='${client_secret}' ARM_TENANT_ID='${tenant_id}' ARM_SUBSCRIPTION_ID='${subscription_id}' terraform -chdir='${repo}' apply ${repo}.plan
	@echo "[+] Terraform applied"

destroy:
	@echo "[-] Run terraform DESTROY"
	@ARM_CLIENT_ID='${client_id}' ARM_CLIENT_SECRET='${client_secret}' ARM_TENANT_ID='${tenant_id}' ARM_SUBSCRIPTION_ID='${subscription_id}' terraform -chdir='${repo}' destroy -var-file=tfvars/default.tfvars
	@echo "[+] Terraform DESTROYED"