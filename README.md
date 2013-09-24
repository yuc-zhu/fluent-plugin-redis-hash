fluent-plugin-redis-hash
========================

Redis output plugin for Fluent event collector


config file
```
<match node.*>
    type redis_hash
    flush_interval 10s
    urls redis://localhost:6379, redis://localhost:6380
    password 123456
    hash_key_pattern %{record['key']}
    hash_field_pattern fixed_field
    hash_value_pattern %{record['value']}
</match>
```
