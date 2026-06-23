select
    category_id,
    category_name,
    legacy_id as category_legacy_id
from {{ ref('stg_categories') }}
