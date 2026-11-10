select merchant_id, valid_from
from {{ ref('dim_merchant_scd2') }}
where length(owner_national_id_hash) != 64
   or not match(owner_mobile_masked, '^09[0-9]{2}\\*{4}[0-9]{3}$')