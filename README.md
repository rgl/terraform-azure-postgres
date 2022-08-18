# About

This creates an example [Azure Database for PostgreSQL Flexible Server](https://azure.microsoft.com/en-us/services/postgresql/) instance using the [Terraform azurerm provider](https://registry.terraform.io/providers/hashicorp/azurerm).

This will:

* Create a public PostgreSQL instance.
* Configure the PostgresSQL instance to require TLS.
* Enable automated backups.
* Set a random `postgres` account password.
* Show how to connect to the created PostgreSQL instance using `psql`.

For further managing the PostgreSQL instance, you could use:

* The [community.postgresql Ansible Collection](https://galaxy.ansible.com/community/postgresql) as in [rgl/ansible-init-postgres](https://github.com/rgl/ansible-init-postgres).

For equivalent examples see:

* pulumi azure-native: https://github.com/rgl/pulumi-typescript-azure-native-postgres

# Usage (Windows)

Install the dependencies:

```powershell
choco install -y azure-cli --version 2.39.0
choco install -y terraform --version 1.2.6
choco install -y postgresql14 --ia '--enable-components commandlinetools'
Import-Module "$env:ChocolateyInstall\helpers\chocolateyInstaller.psm1"
Update-SessionEnvironment
```

Login into Azure:

```powershell
az login
```

List the subscriptions and select the currect one.

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
$env:TF_VAR_region = 'northeurope'
# NB make sure the selected region has this zone available. when its not
#    available, the deployment will fail with InternalServerError.
$env:TF_VAR_zone = '1'
terraform init
terraform plan -out=tfplan
terraform apply tfplan
```

Connect to it:

```powershell
# see https://www.postgresql.org/docs/14/libpq-envars.html
# see https://docs.microsoft.com/en-us/azure/postgresql/flexible-server/how-to-connect-tls-ssl
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

# Reference

* [Terraform azurerm_postgresql_flexible_server resource documentation](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/postgresql_flexible_server)
* [Encrypted connectivity using Transport Layer Security in Azure Database for PostgreSQL - Flexible Server](https://docs.microsoft.com/en-us/azure/postgresql/flexible-server/how-to-connect-tls-ssl)
* [Azure Database for PostgreSQL Product Page](https://azure.microsoft.com/en-us/services/postgresql/)
* [Azure Database for PostgreSQL Flexible Server SKUs](https://docs.microsoft.com/en-us/azure/templates/microsoft.dbforpostgresql/2021-06-01/flexibleservers#sku)
