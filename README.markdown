[![Gem Version](https://img.shields.io/gem/v/dump.svg?style=flat)](https://rubygems.org/gems/dump)
[![Build Status](https://img.shields.io/travis/toy/dump/master.svg?style=flat)](https://travis-ci.org/toy/dump)
[![Code Climate](https://img.shields.io/codeclimate/github/toy/dump.svg?style=flat)](https://codeclimate.com/github/toy/dump)

# DumpRake

Rails app rake and capistrano tasks to create and restore dumps of database and assets.

Tested against rails 2.3, 3.0, 3.1, 3.2, 4.0, 4.1 (rails 2.3 has problems on ruby 2.0 and 2.1).

Works with ruby 1.8.7, ree, 1.9, 2.0, 2.1 (rails 4.0 requires at least ruby 1.9).

## Install

Put in Gemfile if you are using bundler:

    gem 'dump'

Install as plugin for rails 3 (not recommended):

    rails plugin install git://github.com/toy/dump.git

Install as plugin for rails 2:

    script/plugin install git://github.com/toy/dump.git

### Capistrano integration

To get capistrano tasks in rails 3, put in `config/deploy.rb`:

    require 'dump/capistrano'

### Assets config

`config/assets` holds paths of dirs you want to dump in file:

    public/audios
    public/flash
    public/images/upload
    public/videos

Generate in rails 3:

    rails generate assets_config

Generate in rails 2:

    script/generate assets_config

## Capistrano integration

When using cap tasks, dump folder should be in persistent place and be linked to application folder, or you will lose all dumps every deploy. Default recipe creates link on after `deploy:update_code`.

You can use cap dump:* tasks to control dumps on remote server. Don't forget to deploy application to remote server before using dump:remote tasks.
Also you can set custom remote rake binary in your deploy.rb like:

    set :rake, "/custom/rake"

## Usage

    # create dump
    rake dump
    rake dump:create

    # list avaliable dumps
    rake dump:versions

    # restore dump
    rake dump:restore

    # delete old and unfinished dumps (all non tgz files will be deleted if they are not locked)
    rake dump:cleanup

### Environment variables

#### While creating dumps:

`DESC`, `DESCRIPTION` — free form description of dump

    rake dump DESC='uploaded photos'

`TAGS`, `TAG` — comma separated list of tags

    rake dump TAGS='photos,videos'

`ASSETS` — comma or colon separated list of paths or globs to dump

    rake dump ASSETS='public/system:public/images/masks/*'
    rake dump ASSETS='public/system,public/images/masks/*'

`TABLES` — comma separated list of tables to dump or if prefixed by "-" — to skip; by default only sessions table is skipped; schema_info and schema_migrations are always included if they are present

dump all tables except sessions:

    rake dump

dump all tables:

    rake dump TABLES='-'

dump only people, pages and photos tables:

    rake dump TABLES='people,pages,photos'

dump all tables except people and pages:

    rake dump TABLES='-people,pages'

#### While restoring dumps:

`LIKE`, `VER`, `VERSION` — filter dumps by full dump name

    rake dump:versions LIKE='2009'
    rake dump:restore LIKE='2009' # restores last dump matching 2009

`TAGS`, `TAG` — comma separated list of tags
without '+' or '-' — dump should have any of such tags
prefixed with '+' — dump should have every tag with prefix
prefixed with '-' — dump should not have any of tags with prefix

select dumps with tags photos or videos:

    rake dump:restore TAGS='photos,videos'

select dumps with tags photos and videos:

    rake dump:restore TAGS='+photos,+videos'

skip dumps with tags mirror and archive:

    rake dump:restore TAGS='-mirror,-archive'

select dumps with tags photos or videos, with tag important and without mirror:

    rake dump:restore TAGS='photos,videos,+important,-mirror'

`MIGRATE_DOWN` — don't run down for migrations not present in dump if you pass "0", "no" or "false"; pass "reset" to recreate (drop and create) db
by default all migrations which are not present in dump are ran down

don't run down for migrations:

    rake dump:restore MIGRATE_DOWN=no

reset database:

    rake dump:restore MIGRATE_DOWN=reset

`RESTORE_SCHEMA` — don't read/change schema if you pass "0", "no" or "false" (useful to just restore data for table; note that schema info tables are also not restored)

don't restore schema:

    rake dump:restore RESTORE_SCHEMA=no

`RESTORE_TABLES` — works as TABLES, but for restoring

restores only people, pages and photos tables:

    rake dump RESTORE_TABLES='people,pages,photos'

restores all tables except people and pages:

    rake dump TABLES='-people,pages'

`RESTORE_ASSETS` — works as ASSETS, but for restoring

    rake dump RESTORE_ASSETS='public/system/a,public/system/b'
    rake dump RESTORE_ASSETS='public/system/a:public/images/masks/*/new*'

#### For listing dumps:

`LIKE`, `VER`, `VERSION` and `TAG`, `TAGS` as for restoring

`SUMMARY` — output info about dump: "1", "true" or "yes" for basic info, "2" or "schema" to display schema as well

    rake dump:versions SUMMARY=1
    rake dump:versions SUMMARY=full # output schema too

#### For cleanup:

`LIKE`, `VER`, `VERSION` and `TAG`, `TAGS` as for restoring

`LEAVE` — number of dumps to leave

    rake dump:cleanup LEAVE=10
    rake dump:cleanup LEAVE=none

### cap tasks

For all cap commands environment variables are same as for rake tasks

`TRANSFER_VIA` — transfer method (rsync, sftp or scp)
By default transferring task will try to transfer using rsync if it is present, else it will try to use sftp and scp

force transfer using scp:

    cap dump:remote:download TRANSFER_VIA=scp
    cap dump:mirror:down TRANSFER_VIA=scp

`BACKUP`, `AUTOBACKUP`, `AUTO_BACKUP` — no autobackup if you pass "0", "no" or "false"
by default backup is created before mirroring

don't create backup:

    cap dump:mirror:down BACKUP=0
    cap dump:mirror:down AUTOBACKUP=no
    cap dump:mirror:down AUTO_BACKUP=false

#### Basic cap tasks are same as rake tasks

    cap dump:local
    cap dump:local:create
    cap dump:local:restore
    cap dump:local:versions
    cap dump:local:cleanup

    cap dump:remote
    cap dump:remote:create
    cap dump:remote:restore
    cap dump:remote:versions
    cap dump:remote:cleanup

#### Dump exchanging tasks

transfer selected dump to remote server:

    cap dump:local:upload

transfer selected dump to local:

    cap dump:remote:download

#### Mirroring tasks

mirror local to remote (create local dump, upload it to remote and restore it there):

    cap dump:mirror:up

mirror remote to local (create remote dump, download it from remote and restore on local):

    cap dump:mirror:down

#### Backuping tasks

backup remote on local (create remote dump and download it):

    cap dump:backup:create

restore backup (upload dump and restore on remote):

    cap dump:backup:restore

## Copyright

Copyright (c) 2008-2014 Ivan Kuchin. See LICENSE.txt for details.
