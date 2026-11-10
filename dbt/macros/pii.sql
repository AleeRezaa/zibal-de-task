{% macro hash_pii(expr) -%}
    lower(hex(SHA256(concat('{{ env_var("PII_HASH_SALT", "change-me") }}', {{ expr }}))))
{%- endmacro %}

{% macro mask_mobile(expr) -%}
    concat(substring({{ expr }}, 1, 4), '****', substring({{ expr }}, 9, 3))
{%- endmacro %}