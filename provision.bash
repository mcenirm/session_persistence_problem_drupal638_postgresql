#!/bin/bash

set -e

rpmquery --quiet epel-release \
|| yum -y install epel-release

rpmquery --quiet pgdg-centos94 \
|| rpm -Uvh https://download.postgresql.org/pub/repos/yum/9.4/redhat/rhel-6-x86_64/pgdg-centos94-9.4-2.noarch.rpm

pkgs=(
  httpd-devel
  mysql-devel
  mysql-server
  php
  php-bcmath
  php-devel
  php-gd
  php-mbstring
  php-mysql
  php-pdo
  php-pgsql
  php-xml
  postgis2_94
  postgis2_94-client
  postgis2_94-devel
  postgis2_94-utils
  postgresql94-devel
  postgresql94-server
)
missing_pkgs=()

for pkg in "${pkgs[@]}" ; do
  if ! rpmquery --quiet "$pkg" ; then
    missing_pkgs+=( "$pkg" )
  fi
done
  
if [ "${#missing_pkgs[@]}" -gt 0 ] ; then
  yum -y install "${missing_pkgs[@]}"
fi

service httpd start
service mysqld start

if ! [ -f /var/lib/pgsql/9.4/data/PG_VERSION ] ; then
  service postgresql-9.4 initdb
  sed -i.bak -e 's/^\(host.*\)ident$/\1trust/' /var/lib/pgsql/9.4/data/pg_hba.conf
fi

service postgresql-9.4 start

if ! [ -x /usr/local/bin/composer ] ; then
  curl -sLR -o /tmp/composer-setup.php https://getcomposer.org/installer
  php /tmp/composer-setup.php -- --install-dir=/usr/local/bin --filename=composer
fi

if ! [ -x /usr/local/bin/drush ] ; then
  mkdir -p /opt/drush-7.x
  cd /opt/drush-7.x
  /usr/local/bin/composer init --require=drush/drush:7.* -n
  /usr/local/bin/composer config bin-dir /usr/local/bin
  /usr/local/bin/composer install
fi

if ! sudo -i -u postgres psql -t -A -c "select 1 from pg_roles where rolname='root'" | grep -q 1 ; then
  sudo -i -u postgres psql -c "create role root with login superuser"
fi

for v in 36 37 38 ; do
  for d in my pg ; do
    name=d6${v}${d}
    droot=/var/www/html/${name}
    dburl=${d}sql://root@localhost/${name}
    if ! [ -d ${droot} ] ; then
      case "$d" in
        my) (mysqlshow | grep -q -e "$name") && mysqladmin --force drop "$name" ;;
        pg) dropdb --if-exists "$name" ;;
        *) echo >&2 Bad database type: "$d" ; exit 2 ;;
      esac
      cd /var/www/html
      /usr/local/bin/drush -y dl drupal-6.${v}
      mv drupal-6.${v} "$name"
      cd "$droot"
      /usr/local/bin/drush -y site-install --clean-url=0 --db-url=${dburl}
      /usr/local/bin/drush -y user-password admin --password="admin"
    fi
    if [ -d ${droot} ] ; then
      cd "$droot"
      chown -c apache sites/default/files
      if ! [ -d sites/all/modules/sessionsnoop ] ; then
        /usr/local/bin/drush -y make --no-core /vagrant/sessionsnoop.make
        /usr/local/bin/drush -y en sessionsnoop
      fi
      url="http://localhost/${name}/\?q=sessionsnoop"
      cookies="/tmp/cookies-${name}.txt"
      wget_cmd=(
        wget
        --keep-session-cookies
        "--load-cookies=${cookies}"
        "--save-cookies=${cookies}"
        -qO-
        "http://localhost/${name}/?q=sessionsnoop"
      )
      rm -f "$cookies"
      if for i in 1 2 3 4 ; do
          "${wget_cmd[@]}"
        done | fgrep '[counter]' | egrep -o '[0-9]+' | diff >/dev/null -q - <( echo -e "1\n2\n3\n4" ) ; then
        echo "\$_SESSION persistence with Drupal 6.${v} and ${d}sql: PASS"
      else
        echo >&2 "\$_SESSION persistence with Drupal 6.${v} and ${d}sql: FAIL"
      fi
    fi
  done
done
