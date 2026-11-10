{{ config(materialized='view') }}

select
    transaction_id, merchant_id, channel, card_bin, amount, fee_amount, status, installments,
    created_at, updated_at, _loaded_at
from {{ ref('int_transactions') }} final
where _is_deleted = 0