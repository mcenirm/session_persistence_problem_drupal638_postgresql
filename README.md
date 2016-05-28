# Purpose

Verify that Drupal 6.38 broke `$_SESSION` persistence when used with PostgreSQL.

# Steps

1. Create sessionsnoop package:

    tar cf sessionsnoop.tar.gz sessionsnoop

2. Create VM and run tests:

    vagrant up

3. Retest:

    vagrant provision

4. Remove VM:

    vagrant destroy

# Results

    ==> default: $_SESSION persistence with Drupal 6.36 and mysql: PASS
    ==> default: $_SESSION persistence with Drupal 6.36 and pgsql: PASS
    ==> default: $_SESSION persistence with Drupal 6.37 and mysql: PASS
    ==> default: $_SESSION persistence with Drupal 6.37 and pgsql: PASS
    ==> default: $_SESSION persistence with Drupal 6.38 and mysql: PASS
    ==> default: $_SESSION persistence with Drupal 6.38 and pgsql: FAIL
