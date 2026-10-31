[← Return to README](../README.md)

# Security and configuration

## Roles

| Role | Duty | Privilege | Access |
| --- | --- | --- | --- |
| Environment data setup viewer (`OLK_EdsView`) | Inquire into environment data setup (`OLK_EdsView`) | View environment data setup (`OLK_EdsView`) | Read access to all forms. Cannot execute. |
| Environment data setup administrator (`OLK_EdsMaintain`) | Maintain environment data setup (`OLK_EdsMaintain`), Manage environment data setup encryption keys (`OLK_EdsKeyManage`) | Maintain environment data setup (`OLK_EdsMaintain`), Manage environment data setup encryption keys (`OLK_EdsKeyManage`) | Full access to all forms, and execute. Fetch key, Import enrolment, Export enrolment and Encrypt plain values. |
| Environment data setup key service (`OLK_EdsKeyService`) | Call the environment data setup key service (`OLK_EdsKeyService`) | Call the environment data setup key service (`OLK_EdsKeyService`) | Only the [key service](encryption.md#the-key-service). For the user of the Microsoft Entra ID application that the master uses to fetch keys. |

The **Create environment data** group in the Personalize pop-up is shown only to users with access to the Data setup menu item (see [Adding data setup lines from any form](personalization.md)).

The administrator role can write [SQL jobs](sql-jobs.md) that run directly against the database, and [data setup lines](data-setup.md) that change any field of any record. Treat it like System administrator.

Encrypted values are protected separately: see [What this protects against](encryption.md#what-this-protects-against-and-what-it-does-not).

## Configuration key

**OLK Environment data setup** (`OLK_EdsConfigKey`) switches the feature on or off. All setup tables belong to it, and when it is off the Personalize pop-up does not show the group.
