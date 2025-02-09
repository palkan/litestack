class Litesearch::Schema::BasicAdapter
  
  def initialize(schema)
    @schema = schema
    @sql = {}
    enrich_schema
    generate_sql
  end
  
  def name
    @schema[:name]
  end
  
  def table
    @schema[:table]
  end

  def fields
    @schema[:fields]
  end

  def field_names
    @schema[:fields].keys
  end
  
  def active_fields
    @schema[:fields].select{|k, v| v[:weight] != 0 }
  end
  
  def active_field_names
    active_fields.keys
  end
  
  def active_cols_names
    active_fields.collect{|k, v| v[:col]}
  end
  
  def weights
    @schema[:fields].values.collect{|v| v[:weight].to_f }
  end

  def active_weights
    active_fields.values.collect{|v| v[:weight].to_f }
  end

  def tokenizer_sql
    Litesearch::Schema::TOKENIZERS[@schema[:tokenizer]]
  end

  def order_fields(old_schema)
    new_fields = {}
    old_field_names = old_schema.schema[:fields].keys
    old_field_names.each do |name|
      new_fields[name] = @schema[:fields].delete(name) 
    end
    missing_field_names = field_names - old_field_names
    missing_field_names.each do |name|
      new_fields[name] = @schema[:fields].delete(name)
    end   
    @schema[:fields] = new_fields # this should be in order now
    generate_sql
    enrich_schema
  end

  def sql_for(method, *args)
    if sql = @sql[method]
      if sql.is_a? String
        return sql
      elsif sql.is_a? Proc
        return sql.call(*args)
      elsif sql.is_a? Symbol
        return self.send(sql, *args)
      elsif sql.is_a? Litesearch::SchemaChangeException
        raise sql
      end
    end
  end
    
  def generate_sql
    @sql[:create_index] = :create_index_sql
    @sql[:insert] = "INSERT OR REPLACE INTO #{name}(rowid, #{active_col_names_sql}) VALUES (:id, #{active_col_names_var_sql}) RETURNING rowid"
    @sql[:delete] = "DELETE FROM #{name} WHERE rowid = :id"
    @sql[:count] = "SELECT count(*) FROM #{name}(:term)"
    @sql[:count_all] = "SELECT count(*) FROM #{name}"
    @sql[:delete_all] = "DELETE FROM #{name}"
    @sql[:drop] = "DROP TABLE #{name}"
    @sql[:expand_data] = "UPDATE #{name}_data SET block = block || zeroblob(:length) WHERE id = 1"
    @sql[:expand_docsize] = "UPDATE #{name}_docsize SET sz = sz || zeroblob(:length)"
    @sql[:ranks] = :ranks_sql 
    @sql[:set_config_value] = "INSERT OR REPLACE INTO #{name}_config(k, v) VALUES (:key, :value)"
    @sql[:get_config_value] = "SELECT v FROM #{name}_config WHERE k = :key"
    @sql[:search] = "SELECT rowid AS id, -rank AS search_rank FROM #{name}(:term) WHERE rank !=0 ORDER BY rank LIMIT :limit OFFSET :offset"
    @sql[:update_index] = "UPDATE sqlite_schema SET sql = :sql WHERE name = '#{name}'"
    @sql[:update_content_table] = "UPDATE sqlite_schema SET sql = :sql WHERE name = '#{name}_content'"
  end
  
  private
  
  def ranks_sql(active=false)
    if active
      weights_sql = weights.join(', ')
    else
      weights_sql = active_weights.join(', ')      
    end
    "INSERT INTO #{name}(#{name}, rank) VALUES ('rank', 'bm25(#{weights_sql})')"
  end
  
  def active_col_names_sql
    active_field_names.join(', ')
  end
  
  def active_col_names_var_sql
    ":#{active_field_names.join(', :')}"
  end
    
  def col_names_sql
    field_names.join(', ')
  end
  
  def col_names_var_sql
    ":#{field_names.join(', :')}"
  end

  def enrich_schema
  end
    
end

