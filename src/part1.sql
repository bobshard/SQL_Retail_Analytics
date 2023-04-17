CREATE TABLE IF NOT EXISTS personal_information
(
    customer_id            BIGINT PRIMARY KEY,
    customer_name          VARCHAR,
    customer_surname       VARCHAR,
    customer_primary_email VARCHAR,
    customer_primary_phone VARCHAR
);

CREATE TABLE IF NOT EXISTS cards
(
    customer_card_id BIGINT PRIMARY KEY,
    customer_id      BIGINT,
    CONSTRAINT fk_cards_customer_id FOREIGN KEY (customer_id) REFERENCES personal_information (customer_id)
);

CREATE TABLE IF NOT EXISTS transactions
(
    transaction_id       BIGINT PRIMARY KEY,
    customer_card_id     BIGINT,
    transaction_summ     NUMERIC,
    transaction_datetime VARCHAR,
    transaction_store_id BIGINT,
    CONSTRAINT fk_transactions_customer_card_id FOREIGN KEY (customer_card_id) REFERENCES cards (customer_card_id)
);

CREATE TABLE IF NOT EXISTS sku_group
(
    group_id   BIGINT PRIMARY KEY,
    group_name VARCHAR
);

CREATE TABLE IF NOT EXISTS product_grid
(
    sku_id   BIGINT PRIMARY KEY,
    sku_name VARCHAR,
    group_id BIGINT,
    CONSTRAINT fk_product_grid_group_id FOREIGN KEY (group_id) REFERENCES sku_group (group_id)
);

CREATE TABLE IF NOT EXISTS checks
(
    transaction_id    BIGINT,
    sku_id            BIGINT,
    sku_amount        NUMERIC,
    sku_summ          NUMERIC,
    sku_summ_paid     NUMERIC,
    sku_summ_discount NUMERIC,
    CONSTRAINT fk_checks_transaction_id FOREIGN KEY (transaction_id) REFERENCES transactions (transaction_id),
    CONSTRAINT fk_checks_sku_id FOREIGN KEY (sku_id) REFERENCES product_grid (sku_id)
);

CREATE TABLE IF NOT EXISTS stores
(
    transaction_store_id BIGINT,
    sku_id               BIGINT,
    sku_purchase_price   NUMERIC,
    sku_retail_price     NUMERIC,
    CONSTRAINT fk_stores_sku_id FOREIGN KEY (sku_id) REFERENCES product_grid (sku_id)
);

CREATE TABLE IF NOT EXISTS date_of_analysis_formation
(
    analysis_formation VARCHAR
);

CREATE OR REPLACE PROCEDURE IMPORT_FROM_TSV() AS
$$
DECLARE
    import_path VARCHAR   = '/Users/fixierad/Projects/SQL3_RetailAnalitycs_v1.0-2/tmp/';
    import_name VARCHAR[] = ARRAY ['personal_information', 'cards', 'transactions','sku_group','product_grid', 'checks', 'stores','date_of_analysis_formation'];
BEGIN
    FOR i IN 1..ARRAY_LENGTH(import_name, 1)
        LOOP
            EXECUTE FORMAT('COPY %s FROM ''%s%s.tsv'' DELIMITER E''\t'' CSV', import_name[i], import_path,
                           import_name[i]);
        END LOOP;
END;
$$ LANGUAGE plpgsql;

CALL IMPORT_FROM_TSV();

CREATE OR REPLACE PROCEDURE EXPORT_TO_TSV() AS
$$
DECLARE
    export_path VARCHAR   = '/Users/wilfredo/02/SQL3_RetailAnalitycs_v1.0-2/datasets/backup/';
    export_name VARCHAR[] = ARRAY ['personal_information', 'cards', 'transactions','sku_group','product_grid', 'checks', 'stores','date_of_analysis_formation'];
BEGIN
    FOR i IN 1..ARRAY_LENGTH(export_name, 1)
        LOOP
            EXECUTE FORMAT('COPY %s TO ''%s%s.tsv'' WITH DELIMITER E''\t'' CSV', export_name[i], export_path,
                           export_name[i]);
        END LOOP;
END;
$$ LANGUAGE plpgsql;

CALL EXPORT_TO_TSV();