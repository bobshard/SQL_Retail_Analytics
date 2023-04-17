CREATE ROLE Administrator SUPERUSER;

CREATE ROLE Visitor;
GRANT CONNECT ON DATABASE postgres TO Visitor;
GRANT USAGE ON SCHEMA public TO Visitor;
GRANT SELECT ON TABLE cards, checks, date_of_analysis_formation, personal_information, product_grid, sku_group, stores, transactions TO Visitor;

SELECT rolname
FROM pg_roles;

