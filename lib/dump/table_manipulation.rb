require 'dump/env'

module Dump
  # Methods to work with db using ActiveRecord
  module TableManipulation
  protected

    def schema_tables
      %w[schema_info schema_migrations]
    end

    def verify_connection
      connection.verify!(0)
    end

    def quote_table_name(table)
      connection.quote_table_name(table)
    end

    def quote_column_name(column)
      connection.quote_column_name(column)
    end

    def quote_value(value)
      connection.quote(value)
    end

    def clear_table(table_sql)
      connection.delete("DELETE FROM #{table_sql}", 'Clearing table')
    end

    def insert_into_table(table_sql, columns_sql, values_sql)
      values_sql = values_sql.join(',') if values_sql.is_a?(Array)
      sql = "INSERT INTO #{table_sql} #{columns_sql} VALUES #{values_sql}"
      connection.insert(sql, 'Loading dump')
    end

    def fix_sequence!(table)
      return unless connection.respond_to?(:reset_pk_sequence!)

      connection.reset_pk_sequence!(table)
    end

    def join_for_sql(quoted)
      "(#{quoted.join(',')})"
    end

    def columns_insert_sql(columns)
      join_for_sql(columns.map{ |column| quote_column_name(column) })
    end

    def values_insert_sql(values)
      join_for_sql(values.map{ |value| quote_value(value) })
    end

    def avaliable_tables
      connection.tables
    end

    def tables_to_dump
      if Dump::Env[:tables]
        avaliable_tables.select do |table|
          schema_tables.include?(table) ||
            Dump::Env.filter(:tables).pass?(table)
        end
      else
        avaliable_tables - %w[sessions]
      end
    end

    def table_row_count(table)
      sql = "SELECT COUNT(*) FROM #{quote_table_name(table)}"
      connection.select_value(sql).to_i
    end

    CHUNK_SIZE_MIN = 100
    CHUNK_SIZE_MAX = 3_000
    def table_chunk_size(table)
      expected_row_size = table_columns(table).sum do |column|
        case column.type
        when :text
          Math.sqrt(column.limit || 2_147_483_647)
        when :string
          Math.sqrt(column.limit || 255)
        else
          column.limit || 10
        end
      end
      [
        CHUNK_SIZE_MIN,
        (10_000_000 / expected_row_size).round,
        CHUNK_SIZE_MAX,
      ].sort[1]
    end

    def table_columns(table)
      connection.columns(table)
    end

    def table_has_primary_column?(table)
      # bad test for primary column, but primary even for primary column is nil
      table_columns(table).any? do |column|
        column.name == table_primary_key(table) && column.type == :integer
      end
    end

    def table_primary_key(_table)
      'id'
    end

    def each_table_row(table, row_count, &block)
      chunk_size = table_chunk_size(table)
      if table_has_primary_column?(table) && row_count > chunk_size
        # adapted from ActiveRecord::Batches
        primary_key = table_primary_key(table)
        select_where_primary_key =
          sql_select_where_primary_key_by_adapter(table, primary_key, chunk_size)
        rows = select_all_by_sql(select_where_primary_key % '>= 0')
        until rows.blank?
          rows.each(&block)
          break if rows.count < chunk_size

          sql = select_where_primary_key % "> #{rows.last[primary_key].to_i}"
          rows = select_all_by_sql(sql)
        end
      else
        table_rows(table).each(&block)
      end
    end

    def table_rows(table)
      select_all_by_sql("SELECT * FROM #{quote_table_name(table)}")
    end

    def select_all_by_sql(sql)
      connection.select_all(sql)
    end

  private

    def connection
      ActiveRecord::Base.connection
    end

    def sql_select_where_primary_key_by_adapter(table, primary_key, chunk_size)
      quoted_primary_key =
        "#{quote_table_name(table)}.#{quote_column_name(primary_key)}"
      case connection.adapter_name.downcase
      when 'sqlserver'
        "SELECT TOP #{chunk_size} * FROM #{quote_table_name(table)}" \
          " WHERE #{quoted_primary_key} %s" \
          " ORDER BY #{quoted_primary_key} ASC"
      else
        "SELECT * FROM #{quote_table_name(table)}" \
          " WHERE #{quoted_primary_key} %s" \
          " ORDER BY #{quoted_primary_key} ASC" \
          " LIMIT #{chunk_size}"
      end
    end
  end
end
