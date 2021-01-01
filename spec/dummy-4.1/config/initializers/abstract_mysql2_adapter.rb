# https://stackoverflow.com/a/40758542/96823
require 'active_record/connection_adapters/mysql2_adapter'

ActiveRecord::ConnectionAdapters::Mysql2Adapter::NATIVE_DATABASE_TYPES[:primary_key] = 'int(11) auto_increment PRIMARY KEY'
