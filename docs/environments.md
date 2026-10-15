[← Return to README](../README.md)

# Environments

**System administration > Setup > Environment data setup > Environments** (form `OLK_EnvironmentDataSetupTable`)

An environment is one Dynamics 365 Finance and Operations environment that the setup can be executed for, for example `PROD`, `UAT`, `TEST` or `DEV`. Every data setup line, code job and SQL job belongs to one environment.

## Fields

| Field | Description |
| --- | --- |
| Environment id | Identifies the environment, up to 20 characters. Must be unique. |
| Description | Free text. |
| Master environment | The environment where the setup is maintained. Only one environment can be the master; saving a second one fails with *Environment X is already marked as the master environment.* |

The master environment is also what the **Create environment data** button in the Personalize pop-up proposes (see [Adding data setup lines from any form](personalization.md)) and what **Create code jobs** proposes when nothing else is known (see [Code jobs](code-jobs.md)).

## Why there is a master

The setup tables are ordinary tables in the database, so they are copied together with everything else when a database is refreshed. Maintain the setup of every environment in one place, normally the production environment, and mark it as master. After PROD is copied to UAT, the UAT setup arrives with the copy and you execute it in UAT.

Data setup lines point at records by RecId, which a database copy keeps. That is why the lines are created in the environment the data is copied from.

## Buttons

| Button | What it does |
| --- | --- |
| Data setup | Opens [Data setup](data-setup.md) for the selected environment. |
| Code jobs | Opens [Code jobs](code-jobs.md) for the selected environment. |
| SQL jobs | Opens [SQL jobs](sql-jobs.md) for the selected environment. |
| Environment data setup log | Opens the [log](log.md) for the selected environment. |
| Execute environment data setup | Opens the [execution dialog](execute.md) with the selected environment filled in. |

The setup tables are shared across companies, so the list is the same in every company.
