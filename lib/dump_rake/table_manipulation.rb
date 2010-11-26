class DumpRake
  module TableManipulation
  protected

    def schema_tables
      %w(schema_info schema_migrations)
    end

    def verify_connection
      ActiveRecord::Base.connection.verify!(0)
    end


    def quote_table_name(table)
      ActiveRecord::Base.connection.quote_table_name(table)
    end

    def quote_column_name(column)
      ActiveRecord::Base.connection.quote_column_name(column)
    end

    def quote_value(value)
      ActiveRecord::Base.connection.quote(value)
    end


    def clear_table(table_sql)
      ActiveRecord::Base.connection.delete("DELETE FROM #{table_sql}", 'Clearing table')
    end

    def insert_into_table(table_sql, columns_sql, values_sql)
      values_sql = values_sql.join(',') if values_sql.is_a?(Array)
      ActiveRecord::Base.connection.insert("INSERT INTO #{table_sql} #{columns_sql} VALUES #{values_sql}", 'Loading dump')
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
      ActiveRecord::Base.connection.tables
    end

    def tables_to_dump
      if DumpRake::Env[:tables]
        env_tables = DumpRake::Env[:tables].dup
        prefix = env_tables.slice!(/^\-/)
        candidates = env_tables.split(',').map(&:strip).map(&:downcase).uniq.reject(&:blank?)
        if prefix
          avaliable_tables - (candidates - schema_tables)
        else
          avaliable_tables & (candidates | schema_tables)
        end
      else
        avaliable_tables - %w(sessions)
      end
    end

    def table_row_count(table)
      ActiveRecord::Base.connection.select_value("SELECT COUNT(*) FROM #{quote_table_name(table)}").to_i
    end

    CHUNK_SIZE_MIN = 100 unless const_defined?(:CHUNK_SIZE_MIN)
    CHUNK_SIZE_MAX = 3_000 unless const_defined?(:CHUNK_SIZE_MAX)
    def table_chunk_size(table)
      expected_row_size = table_columns(table).map do |column|
        case column.type
        when :text
          Math.sqrt(column.limit || 2_147_483_647)
        when :string
          Math.sqrt(column.limit || 255)
        else
          column.limit || 10
        end
      end.sum
      [[(10_000_000 / expected_row_size).round, CHUNK_SIZE_MIN].max, CHUNK_SIZE_MAX].min
    end

    def table_columns(table)
      ActiveRecord::Base.connection.columns(table)
    end

    def table_has_primary_column?(table)
      # bad test for primary column, but primary even for primary column is nil
      table_columns(table).any?{ |column| column.name == table_primary_key(table) && column.type == :integer }
    end

    def table_primary_key(table)
      'id'
    end

    def each_table_row(table, row_count, &block)
      if table_has_primary_column?(table) && row_count > (chunk_size = table_chunk_size(table))
        # adapted from ActiveRecord::Batches
        primary_key = table_primary_key(table)
        quoted_primary_key = "#{quote_table_name(table)}.#{quote_column_name(primary_key)}"
        select_where_primary_key =
          "SELECT * FROM #{quote_table_name(table)}" +
            " WHERE #{quoted_primary_key} %s" +
            " ORDER BY #{quoted_primary_key} ASC" +
            " LIMIT #{chunk_size}"
        rows = select_all_by_sql(select_where_primary_key % '>= 0')
        until rows.blank?
          rows.each(&block)
          break if rows.length < chunk_size
          rows = select_all_by_sql(select_where_primary_key % "> #{rows.last[primary_key].to_i}")
        end
      else
        table_rows(table).each(&block)
      end
    end

    def table_rows(table)
      select_all_by_sql("SELECT * FROM #{quote_table_name(table)}")
    end

    def select_all_by_sql(sql)
      ActiveRecord::Base.connection.select_all(sql)
    end
  end
end
