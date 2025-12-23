CREATE TABLE default.ddos_whitelist_nets (
    cidr String,
    description String
) ENGINE = MergeTree()
ORDER BY cidr;