{{ config(materialized='view') }}

select merchant_id, merchant_name, mcc, province, risk_level,
       owner_national_id_hash, owner_mobile_masked, valid_from as current_since
from {{ ref('dim_merchant_scd2') }}
where is_current and is_deleted = 0