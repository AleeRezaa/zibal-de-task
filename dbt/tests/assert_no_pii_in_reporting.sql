-- no PII-looking columns may exist in the reporting layer
select database, table, name
from system.columns
where database = 'reporting'
  and (name ilike '%national%' or name ilike '%mobile%' or name ilike '%phone%')