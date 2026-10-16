# OlkInc-D365FO-EDS

Environment data setup for Dynamics 365 Finance and Operations. After a database is copied from one environment to another (for example PROD to UAT), it writes the environment specific values back: field values, code jobs and SQL jobs. Every run is logged.

## How it works

1. In the production environment (the **master**), create an [environment](docs/environments.md) record for each environment you refresh, for example `UAT` and `TEST`.
2. For each environment, record what must differ there:
   - [Data setup](docs/data-setup.md) lines: a value for one field of one record, for example a service URL or an email address. The quickest way to add one is **Create environment data** in the [Personalize pop-up](docs/personalization.md) of the field.
   - [Code jobs](docs/code-jobs.md): X++ methods, for example enabling users or releasing batch jobs. Their settings are [Environment default values](docs/default-values.md).
   - [SQL jobs](docs/sql-jobs.md): single UPDATE, INSERT or DELETE statements for bulk changes.
3. Refresh the target environment from production. The setup is copied along with the rest of the database.
4. In the target environment, run [Execute environment data setup](docs/execute.md) for it.
5. Check the [log](docs/log.md).

## Documentation

All forms are under **System administration > Setup > Environment data setup**. The pages for the forms and the Personalize pop-up have annotated screenshots with numbered steps.

| Form or mechanism | Document |
| --- | --- |
| Environments | [docs/environments.md](docs/environments.md) |
| Data setup | [docs/data-setup.md](docs/data-setup.md) |
| Create environment data (Personalize pop-up) | [docs/personalization.md](docs/personalization.md) |
| Code jobs | [docs/code-jobs.md](docs/code-jobs.md) |
| Writing a code job (developer guide) | [docs/writing-code-jobs.md](docs/writing-code-jobs.md) |
| SQL jobs | [docs/sql-jobs.md](docs/sql-jobs.md) |
| Environment default values | [docs/default-values.md](docs/default-values.md) |
| Execute environment data setup | [docs/execute.md](docs/execute.md) |
| Environment data setup log | [docs/log.md](docs/log.md) |
| Security and configuration key | [docs/security.md](docs/security.md) |
| Tests | [docs/tests.md](docs/tests.md) |

## Repository layout

```
Metadata/
  OlkInc-D365FO-EDS/        the model
  OlkInc-D365FO-EDS-Test/   tests and the sample code jobs
docs/                       the documentation
```

Both models use the standard PackagesLocalDirectory layout.

| Model | Depends on |
| --- | --- |
| OlkInc-D365FO-EDS | ApplicationPlatform, ApplicationFoundation |
| OlkInc-D365FO-EDS-Test | ApplicationPlatform, ApplicationFoundation, ApplicationSuite, OlkInc-D365FO-EDS |

## Installing

1. Copy or link both folders under `Metadata` into PackagesLocalDirectory, or map them in your source control workspace.
2. Build OlkInc-D365FO-EDS (and OlkInc-D365FO-EDS-Test on development environments) and synchronize the database.
3. Check that the configuration key **OLK Environment data setup** is on, and assign the [roles](docs/security.md).

Deploy only OlkInc-D365FO-EDS to production; the test model is for development and test environments.

## License

See [LICENSE](LICENSE).
