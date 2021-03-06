﻿/*
* @author: Justin Leto
* @date: June 15, 2013
*
* function: _utility.fn_missing_foreignkey_indexes(create_indexes boolean)
*
* description:
* 	Foreign key columns are a special case that demands they have indexes.
* 	This function searches all foreign keys in the current schema and allows the user to
*	control, through the create_indexes parameter, whether the function creates or reports
*	the missing indexes on foreign key indexes.
*
* parameters:
*	create_indexes (boolean): Flag to control whether missing indexes are created or just reported.
*							  True - Create the missing indexes.
*							  False - Report the missing indexes but do not create.
*
* usage:
*/
/*
	--reporting
	do $$
	begin
		perform _utility.fn_missing_foreignkey_indexes(false);
	end $$;
	
	--creating indexes:
	do $$
	begin
		perform _utility.fn_missing_foreignkey_indexes(true);
	end $$;
*/

/* Check for _utility schema. If it doesn't exist, create it. */
do $$
begin
	if not (SELECT exists(select schema_name FROM information_schema.schemata WHERE schema_name = '_utility'))
	then
		create Schema _utility;
	end if;
end $$;

create or replace function _utility.fn_missing_foreignkey_indexes(create_indexes boolean)
returns boolean as
$BODY$
declare create_index_sql text = '';
		missing_index_count int = 0;
begin

	select into missing_index_count, create_index_sql
			index_statements.missing_index_count, create_index_statements from 
	(
		
		select 
				/* Get missing index count */
				count(*) missing_index_count,
				/* Construct the create index statements with the naming convention tablename_columnname_idx.
				   Note: '_' is stripped from table and column names. */
				array_to_string(array_agg('create index ' || replace(foreign_keys.table_name, '_', '') || '_' || replace(foreign_keys.column_name,'_','') || '_idx on ' || current_schema() || '.' || foreign_keys.table_name || ' (' || foreign_keys.column_name || ');'), E'\n') as create_index_statements
		from (
			/* Get all foreign keys */
			select 	tc.table_schema,
					tc.table_name,
					kcu.column_name
			from
				information_schema.table_constraints as tc
				inner join information_schema.key_column_usage as kcu
					on tc.constraint_name = kcu.constraint_name
				inner join information_schema.constraint_column_usage as ccu
					on ccu.constraint_name = tc.constraint_name
			where constraint_type = 'FOREIGN KEY'
			group by tc.table_schema,
					 tc.table_name,
					 kcu.column_name
			order by tc.table_schema,
					 tc.table_name,
					 kcu.column_name
			) foreign_keys
		left outer join (
			/* Get all existing indexes */
			select n.nspname as table_schema,
				t.relname as table_name,
				a.attname as column_name,
				i.relname as index_name
			from
				pg_class t,
				pg_class i,
				pg_index ix,
				pg_attribute a,
				pg_namespace n
			where
				t.oid = ix.indrelid
				and i.oid = ix.indexrelid
				and a.attrelid = t.oid
				and a.attnum = ANY(ix.indkey)
				and t.relkind = 'r'
				and n.oid = t.relnamespace
			group by n.nspname,
					 t.relname,
					 a.attname,
					 i.relname
			order by
				n.nspname,
				t.relname,
				a.attname,
				i.relname
			) existing_indexes
			on foreign_keys.table_schema = existing_indexes.table_schema
			and foreign_keys.table_name = existing_indexes.table_name
			and foreign_keys.column_name = existing_indexes.column_name
			/* Filter foreign key records where corresponding table and column has no index */
			where existing_indexes.index_name IS NULL

	) index_statements;

	begin

		/* Test if missing foreign key indexes were found */
		if missing_index_count > 0
		then
			if create_indexes then
				raise notice E'\n% missing foreign key indexes will be created: \n%', missing_index_count, create_index_sql;
				/* Create missing foreign key indexes */
				execute create_index_sql;
				raise notice E'\nIndexes created successfully.';
			else
				raise notice E'\nThere are % missing foreign key indexes.\nRun this function with a create_indexes paramter set to true to execute the following statements: \n%', missing_index_count, create_index_sql;			
			end if;
		else
			raise notice E'\nThere are no missing foreign key indexes.';
		end if;

		/* Catch and raise notice of exceptions */
		exception when others then
			raise notice E'\n% %', SQLERRM, SQLSTATE;
			/* Report failure */
			return false;
	end;

	/* Report success */
	return true;
	
end;
$BODY$ language plpgsql;
