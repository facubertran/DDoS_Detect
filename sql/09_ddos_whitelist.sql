CREATE TABLE default.ddos_whitelist (
    ip IPv4,
    description String,
    added_at DateTime DEFAULT now()
) ENGINE = MergeTree()
ORDER BY ip;