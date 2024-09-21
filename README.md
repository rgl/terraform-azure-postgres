# About

[![Lint](https://github.com/rgl/terraform-azure-postgres/actions/workflows/lint.yml/badge.svg)](https://github.com/rgl/terraform-azure-postgres/actions/workflows/lint.yml)

This creates an example [Azure Database for PostgreSQL Flexible Server](https://azure.microsoft.com/en-us/services/postgresql/) instance using the [Terraform azurerm provider](https://registry.terraform.io/providers/hashicorp/azurerm).

This will:

* Create a public PostgreSQL instance.
* Configure the PostgresSQL instance to require TLS.
* Enable automated backups.
* Set a random `postgres` account password.
* Show how to connect to the created PostgreSQL instance using `psql`.

For further managing the PostgreSQL instance, you could use:

* The [cyrilgdn/postgresql Terraform provider](https://registry.terraform.io/providers/cyrilgdn/postgresql).
* The [community.postgresql Ansible collection](https://galaxy.ansible.com/community/postgresql) as in [rgl/ansible-init-postgres](https://github.com/rgl/ansible-init-postgres).

For equivalent examples see:

* [pulumi azure-native](https://github.com/rgl/pulumi-typescript-azure-native-postgres)
* [pulumi google-native](https://github.com/rgl/pulumi-typescript-google-postgres)
* [terraform gcp](https://github.com/rgl/terraform-gcp-cloud-sql-postgres)

# Table Of Contents

* [Usage (Ubuntu)](#usage-ubuntu)
* [Usage (Windows)](#usage-windows)
* [References](#references)

# Usage (Ubuntu)

Install dependencies:

* `az` (see [my ubuntu ansible azure-client role](https://github.com/rgl/my-ubuntu-ansible-playbooks/tree/main/roles/azure-client))
* `terraform` (see [my ubuntu ansible terraform role](https://github.com/rgl/my-ubuntu-ansible-playbooks/tree/main/roles/terraform))

Install more dependencies:

```bash
sudo apt-get install -y postgresql-client
sudo apt-get install -y jq
```

Login into Azure:

```bash
az login
```

List the subscriptions:

```bash
az account list --all
az account show
```

Set the subscription:

```bash
export ARM_SUBSCRIPTION_ID="<YOUR-SUBSCRIPTION-ID>"
az account set --subscription "$ARM_SUBSCRIPTION_ID"
```

Provision the example infrastructure:

```bash
export CHECKPOINT_DISABLE='1'
export TF_LOG='TRACE'
export TF_LOG_PATH='terraform.log'
# set the region.
export TF_VAR_location='northeurope'
# show the available zones in the given region/location.
az postgres flexible-server list-skus \
  --location $TF_VAR_location \
  | jq -r '.[].supportedServerEditions[].supportedServerSkus[].supportedZones'
# set the zone.
# NB make sure the selected region has this zone available. when its not
#    available, the deployment will fail with InternalServerError.
export TF_VAR_zone='1'
# initialize.
terraform init -lockfile=readonly
# provision.
terraform plan -out=tfplan
terraform apply tfplan
```

Connect to it:

```bash
# see https://www.postgresql.org/docs/16/libpq-envars.html
# see https://learn.microsoft.com/en-us/azure/postgresql/flexible-server/how-to-connect-tls-ssl
# see https://learn.microsoft.com/en-us/azure/postgresql/flexible-server/concepts-networking-ssl-tls#download-root-ca-certificates-and-update-application-clients-in-certificate-pinning-scenarios
cacerts_path="cacerts.pem"
cacerts_urls=(
  https://www.microsoft.com/pkiops/certs/Microsoft%20RSA%20Root%20Certificate%20Authority%202017.crt
  https://cacerts.digicert.com/DigiCertGlobalRootG2.crt.pem
  https://cacerts.digicert.com/DigiCertGlobalRootCA.crt
)
user_agent="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36"
{
  for url in "${cacerts_urls[@]}"; do
    if [[ $url == *.crt ]]; then
      wget -qO- --user-agent="$user_agent" "$url" | openssl x509 -inform DER -outform PEM
    else
      wget -qO- --user-agent="$user_agent" "$url"
    fi
  done
} > "$cacerts_path"
export PGSSLMODE='verify-full'
export PGSSLROOTCERT="$cacerts_path"
export PGHOST="$(terraform output --raw fqdn)"
export PGDATABASE='postgres'
export PGUSER='postgres'
export PGPASSWORD="$(terraform output --raw password)"
psql
```

Execute example queries:

```sql
select version();
select current_user;
select case when ssl then concat('YES (', version, ')') else 'NO' end as ssl from pg_stat_ssl where pid=pg_backend_pid();
show password_encryption;
select * from azure_roles_authtype() where rolename=current_user;
```

Exit the `psql` session:

```sql
exit
```

Destroy everything:

```bash
terraform destroy
```

# Usage (Windows)

Install the dependencies:

```powershell
choco install -y azure-cli --version 2.64.0
choco install -y terraform --version 1.9.6
choco install -y tflint --version 0.53.0
choco install -y postgresql16 --version 16.1.0 `
    --install-arguments "'$(@(
            '--enable-components commandlinetools'
            '--disable-components server'
        ) -join ' ')'"
choco install -y jq --version 1.7.1
Import-Module "$env:ChocolateyInstall\helpers\chocolateyInstaller.psm1"
Update-SessionEnvironment
```

Login into Azure:

```powershell
az login
```

List the subscriptions and select the correct one.

```powershell
az account list --all
az account show
az account set --subscription <YOUR-SUBSCRIPTION-ID>
```

Provision the example infrastructure:

```powershell
$env:CHECKPOINT_DISABLE = '1'
$env:TF_LOG = 'TRACE'
$env:TF_LOG_PATH = 'terraform.log'
# set the region.
$env:TF_VAR_location = 'northeurope'
# show the available zones in the given region/location.
az postgres flexible-server list-skus `
  --location $env:TF_VAR_location `
  | jq -r '.[].zone'
# set the zone.
# NB make sure the selected region has this zone available. when its not
#    available, the deployment will fail with InternalServerError.
$env:TF_VAR_zone = '1'
tflint --init
tflint --loglevel trace
terraform init
# provision.
terraform plan -out=tfplan
terraform apply tfplan
```

Connect to it:

```powershell
# see https://www.postgresql.org/docs/16/libpq-envars.html
# see https://learn.microsoft.com/en-us/azure/postgresql/flexible-server/how-to-connect-tls-ssl
$cacertsUrl = 'https://dl.cacerts.digicert.com/DigiCertGlobalRootCA.crt.pem'
$cacertsPath = Split-Path -Leaf $cacertsUrl
(New-Object Net.WebClient).DownloadFile($cacertsUrl, $cacertsPath)
$env:PGSSLMODE = 'verify-full'
$env:PGSSLROOTCERT = $cacertsPath
$env:PGHOST = terraform output --raw fqdn
$env:PGDATABASE = 'postgres'
$env:PGUSER = 'postgres'
$env:PGPASSWORD = terraform output --raw password
psql
```

Execute example queries:

```sql
select version();
select current_user;
select case when ssl then concat('YES (', version, ')') else 'NO' end as ssl from pg_stat_ssl where pid=pg_backend_pid();
```

Exit the `psql` session:

```sql
exit
```

Destroy everything:

```powershell
terraform destroy
```

# References

* [Terraform azurerm_postgresql_flexible_server resource documentation](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/postgresql_flexible_server)
* [Encrypted connectivity using Transport Layer Security in Azure Database for PostgreSQL - Flexible Server](https://learn.microsoft.com/en-us/azure/postgresql/flexible-server/how-to-connect-tls-ssl)
* [Azure Database for PostgreSQL Product Page](https://azure.microsoft.com/en-us/services/postgresql/)
* [Azure Database for PostgreSQL Flexible Server SKUs](https://learn.microsoft.com/en-us/azure/templates/microsoft.dbforpostgresql/2022-12-01/flexibleservers#sku)
* [Azure Database for PostgreSQL Release Notes](https://learn.microsoft.com/en-us/azure/postgresql/flexible-server/release-notes)
