{{ config(materialized='view') }}

select *, valid_to = toDateTime64('2999-12-31 00:00:00', 6, 'UTC') as is_current
from (
    select
        merchant_id, merchant_name, mcc, province, risk_level,
        owner_national_id_hash, owner_mobile_masked,
        _is_deleted as is_deleted,
        valid_from,
        leadInFrame(valid_from, 1, toDateTime64('2999-12-31 00:00:00', 6, 'UTC')) over (
            partition by merchant_id order by valid_from
            rows between unbounded preceding and unbounded following
        ) as valid_to
    from {{ ref('int_merchant_versions') }} final
)