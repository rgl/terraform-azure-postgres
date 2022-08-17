# About

This creates an example Azure Database for PostgreSQL Flexible Server instance using the terraform azurerm provider.

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
terraform init
terraform plan -out=tfplan
terraform apply tfplan
```

Connect to it:

```powershell
# see https://www.postgresql.org/docs/14/libpq-envars.html
# see https://cloud.google.com/sql/docs/postgres/connect-admin-ip?authuser=2#connect-ssl
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
