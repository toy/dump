# frozen_string_literal: true

require 'spec_helper'
require 'dump/table_manipulation'

describe Dump::TableManipulation do
  include described_class

  describe 'schema_tables' do
    it 'returns schema_tables' do
      expect(schema_tables).to eq(%w[schema_info schema_migrations])
    end
  end

  describe 'verify_connection' do
    it 'returns result of connection.verify!' do
      expect(connection).to receive(:verify!).and_return(:result)
      expect(verify_connection).to eq(:result)
    end
  end

  describe 'quote_table_name' do
    it 'returns result of connection.quote_table_name' do
      expect(connection).to receive(:quote_table_name).with('first').and_return('`first`')
      expect(quote_table_name('first')).to eq('`first`')
    end
  end

  describe 'quote_column_name' do
    it 'returns result of connection.quote_column_name' do
      expect(connection).to receive(:quote_column_name).with('first').and_return('`first`')
      expect(quote_column_name('first')).to eq('`first`')
    end
  end

  describe 'quote_value' do
    it 'returns result of connection.quote_value' do
      expect(connection).to receive(:quote).with('first').and_return('`first`')
      expect(quote_value('first')).to eq('`first`')
    end
  end

  describe 'clear_table' do
    it 'calls connection.delete with sql for deleting everything from table' do
      expect(connection).to receive(:delete).with('DELETE FROM `first`', anything)
      clear_table('`first`')
    end
  end

  describe 'insert_into_table' do
    it 'calls connection.insert with sql for insert if values is string' do
      expect(connection).to receive(:insert).with('INSERT INTO `table` (`c1`,`c2`) VALUES (`v1`,`v2`)', anything)
      insert_into_table('`table`', '(`c1`,`c2`)', '(`v1`,`v2`)')
    end

    it 'calls connection.insert with sql for insert if values is array' do
      expect(connection).to receive(:insert).with('INSERT INTO `table` (`c1`,`c2`) VALUES (`v11`,`v12`),(`v21`,`v22`)', anything)
      insert_into_table('`table`', '(`c1`,`c2`)', ['(`v11`,`v12`)', '(`v21`,`v22`)'])
    end
  end

  describe 'join_for_sql' do
    it "converts array ['`a`', '`b`'] to \"(`a`,`b`)\"" do
      expect(join_for_sql(%w[`a` `b`])).to eq('(`a`,`b`)')
    end
  end

  describe 'columns_insert_sql' do
    it 'returns columns sql part for insert' do
      expect(self).to receive(:quote_column_name).with('a').and_return('`a`')
      expect(self).to receive(:quote_column_name).with('b').and_return('`b`')

      expect(columns_insert_sql(%w[a b])).to eq('(`a`,`b`)')
    end
  end

  describe 'values_insert_sql' do
    it 'returns values sql part for insert' do
      expect(self).to receive(:quote_value).with('a').and_return('`a`')
      expect(self).to receive(:quote_value).with('b').and_return('`b`')

      expect(values_insert_sql(%w[a b])).to eq('(`a`,`b`)')
    end
  end

  describe 'tables_to_dump' do
    it 'calls connection.tables' do
      expect(connection).to receive(:tables).and_return([])
      tables_to_dump
    end

    it 'excludes sessions table from result' do
      expect(connection).to receive(:tables).and_return(%w[first second schema_info schema_migrations sessions])
      expect(tables_to_dump).to eq(%w[first second schema_info schema_migrations])
    end

    describe 'with user defined tables' do
      before do
        expect(connection).to receive(:tables).and_return(%w[first second schema_info schema_migrations sessions])
      end

      it 'selects certain tables' do
        Dump::Env.with_env(:tables => 'first,third,-fifth') do
          expect(tables_to_dump).to eq(%w[first schema_info schema_migrations])
        end
      end

      it 'selects skip certain tables' do
        Dump::Env.with_env(:tables => '-first,third,-fifth') do
          expect(tables_to_dump).to eq(%w[second schema_info schema_migrations sessions])
        end
      end

      it 'does not exclude sessions table from result if asked to exclude nothing' do
        Dump::Env.with_env(:tables => '-') do
          expect(tables_to_dump).to eq(%w[first second schema_info schema_migrations sessions])
        end
      end

      it 'does not exclude schema tables' do
        Dump::Env.with_env(:tables => '-second,schema_info,schema_migrations') do
          expect(tables_to_dump).to eq(%w[first schema_info schema_migrations sessions])
        end
      end

      it 'does not exclude schema tables ever if asked to dump only certain tables' do
        Dump::Env.with_env(:tables => 'second') do
          expect(tables_to_dump).to eq(%w[second schema_info schema_migrations])
        end
      end
    end
  end

  describe 'table_row_count' do
    it 'ruturns row count for table' do
      expect(connection).to receive(:select_value).with("SELECT COUNT(*) FROM #{quote_table_name('first')}").and_return('666')
      expect(table_row_count('first')).to eq(666)
    end
  end

  describe 'table_chunk_size' do
    it 'returns chunk_size based on estimated average for row size' do
      expect(self).to receive(:table_columns).with('first').and_return(
        ([double(:column, :type => :integer, :limit => nil)] * 3) +
        ([double(:column, :type => :string, :limit => nil)] * 3) +
        [double(:column, :type => :text, :limit => nil)]
      )
      expect(table_chunk_size('first')).to satisfy{ |n|
        (described_class::CHUNK_SIZE_MIN..described_class::CHUNK_SIZE_MAX).include?(n)
      }
    end

    it 'does not return value less than CHUNK_SIZE_MIN' do
      expect(self).to receive(:table_columns).with('first').and_return(
        [double(:column, :type => :text, :limit => nil)] * 100
      )
      expect(table_chunk_size('first')).to eq(described_class::CHUNK_SIZE_MIN)
    end

    it 'does not return value more than CHUNK_SIZE_MAX' do
      expect(self).to receive(:table_columns).with('first').and_return(
        [double(:column, :type => :boolean, :limit => 1)] * 10
      )
      expect(table_chunk_size('first')).to eq(described_class::CHUNK_SIZE_MAX)
    end
  end

  describe 'table_columns' do
    it 'returns table column definitions' do
      columns = [double(:column), double(:column), double(:column)]
      expect(connection).to receive(:columns).with('first').and_return(columns)
      expect(table_columns('first')).to eq(columns)
    end
  end

  describe 'table_has_primary_column?' do
    it 'returns true only if table has column with name id and type :integer' do
      expect(self).to receive(:table_primary_key).at_least(3).times.and_return('id')

      expect(self).to receive(:table_columns).with('first').and_return([double(:column, :name => 'id', :type => :integer), double(:column, :name => 'title', :type => :integer)])
      expect(table_has_primary_column?('first')).to be_truthy

      expect(self).to receive(:table_columns).with('second').and_return([double(:column, :name => 'id', :type => :string), double(:column, :name => 'title', :type => :integer)])
      expect(table_has_primary_column?('second')).to be_falsey

      expect(self).to receive(:table_columns).with('third').and_return([double(:column, :name => 'name', :type => :integer), double(:column, :name => 'title', :type => :integer)])
      expect(table_has_primary_column?('third')).to be_falsey
    end
  end

  describe 'table_primary_key' do
    it 'returns id' do
      expect(table_primary_key('first')).to eq('id')
      expect(table_primary_key(nil)).to eq('id')
    end
  end

  describe 'each_table_row' do
    before do
      @row_count = 550
      @rows = Array.new(@row_count){ |i| {'id' => i.succ.to_s} }
    end

    def verify_getting_rows
      i = 0
      each_table_row('first', @row_count) do |row|
        expect(row).to eq('id' => i.succ.to_s)
        i += 1
      end
      expect(i).to eq(@row_count)
    end

    {
      'whatever' =>
        'SELECT * FROM [TN] WHERE [PK] %s ORDER BY [PK] ASC LIMIT 100',
      'SQLServer' =>
        'SELECT TOP 100 * FROM [TN] WHERE [PK] %s ORDER BY [PK] ASC',
    }.each do |adapter_name, sql_template|
      it 'gets rows in chunks if table has primary column and chunk size is less than row count' do
        allow(connection).to receive(:adapter_name).and_return(adapter_name)
        expect(self).to receive(:table_has_primary_column?).with('first').and_return(true)
        expect(self).to receive(:table_chunk_size).with('first').and_return(100)
        replacements = {
          '[TN]' => quote_table_name('first'),
          '[PK]' => "#{quote_table_name('first')}.#{quote_column_name(table_primary_key('first'))}",
        }
        sql = sql_template.gsub(/\[[A-Z]+\]/){ |m| replacements[m] }

        expect(self).to receive(:select_all_by_sql).with(sql % '>= 0').and_return(@rows[0, 100])
        5.times do |i|
          last_primary_key = (i * 100) + 100
          expect(self).to receive(:select_all_by_sql).with(sql % "> #{last_primary_key}").and_return(@rows[last_primary_key, 100])
        end

        verify_getting_rows
      end
    end

    def verify_getting_rows_in_one_pass
      expect(self).to receive(:select_all_by_sql).with("SELECT * FROM #{quote_table_name('first')}").and_return(@rows)
      verify_getting_rows
    end

    it 'gets rows in one pass if table has primary column but chunk size is not less than row count' do
      expect(self).to receive(:table_has_primary_column?).with('first').and_return(true)
      expect(self).to receive(:table_chunk_size).with('first').and_return(3_000)
      verify_getting_rows_in_one_pass
    end

    it 'gets rows in one pass if table has no primary column' do
      expect(self).to receive(:table_has_primary_column?).with('first').and_return(false)
      allow(self).to receive(:table_chunk_size).with('first').and_return(10_000)
      verify_getting_rows_in_one_pass
    end
  end

  describe 'select_all_by_sql' do
    it 'returns all rows returned by database' do
      rows = [double(:row), double(:row), double(:row)]
      expect(connection).to receive(:select_all).with('SELECT * FROM abc WHERE x = y').and_return(rows)
      expect(select_all_by_sql('SELECT * FROM abc WHERE x = y')).to eq(rows)
    end
  end
end
