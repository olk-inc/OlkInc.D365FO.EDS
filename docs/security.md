[← Return to README](../README.md)

# Security and configuration

## Roles

| Role | Duty | Privilege | Access |
| --- | --- | --- | --- |
| Environment data setup viewer (`OLK_EdsView`) | Inquire into environment data setup (`OLK_EdsView`) | View environment data setup (`OLK_EdsView`) | Read access to all forms. Cannot execute. |
| Environment data setup administrator (`OLK_EdsMaintain`) | Maintain environment data setup (`OLK_EdsMaintain`) | Maintain environment data setup (`OLK_EdsMaintain`) | Full access to all forms, and execute. |

The **Create environment data** group in the Personalize pop-up is shown only to users with access to the Data setup menu item (see [Adding data setup lines from any form](personalization.md)).

The administrator role can write [SQL jobs](sql-jobs.md) that run directly against the database, and [data setup lines](data-setup.md) that change any field of any record. Treat it like System administrator.

## Configuration key

**OLK Environment data setup** (`OLK_EdsConfigKey`) switches the feature on or off. All setup tables belong to it, and when it is off the Personalize pop-up does not show the group.
