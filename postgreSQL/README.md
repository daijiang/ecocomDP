#EcoCom DP - posgreSQL
---

Directory contains the postgreSQL implementation of EDI's design pattern for ecological community survey data (ecocomDP)

ecocomDP is composed of 7 tables, which can be linked via their indexes. An RDB implmentation illustrates this well, but of course, there are other equally usable mechanisms (eg, R data frames).

file: create_7tables_ecocomDP_postgres.sql
creates the seven tables (see ../documentation) in a pre-existing posgtres schema called "ecocom_dp".
Example is given for a read-only user, called "read_only_user", and an owner ("mob").

The "html" directory contains model documentation generated by a java program called schemaSpy (http://schemaspy.sourceforge.net/)

