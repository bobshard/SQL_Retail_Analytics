CREATE OR REPLACE FUNCTION part5_increase_frequency(first_date_p DATE, last_date_p DATE,
                                                    amount_tr INTEGER,
                                                    max_churn_rate NUMERIC, max_discount_share NUMERIC, margin NUMERIC
)
    RETURNS TABLE
            (
                customer_id                 BIGINT,
                Start_Date                  DATE,
                End_Date                    DATE,
                Required_Transactions_Count NUMERIC,
                Group_Name                  VARCHAR,
                Offer_Discount_Depth        NUMERIC
            )
AS
$$
DECLARE
    amount_day INTEGER = (last_date_p - first_date_p);
BEGIN
    RETURN QUERY (SELECT pe.customer_id,
                         first_date_p,
                         last_date_p,
                         part5_target_value_transaction(pe.customer_id, amount_day, amount_tr),
                         part5_group_name(pe.customer_id, max_churn_rate, max_discount_share , margin),
                         part5_offer_disc(pe.customer_id, max_churn_rate, max_discount_share, margin)
                  FROM personal_information pe);
END ;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION part5_target_value_transaction(_customer_id BIGINT, amount_day INTEGER, amount_tr INTEGER) RETURNS NUMERIC AS
$$
BEGIN
    RETURN (SELECT ROUND((amount_day / (NULLIF(customer_frequency, 0))), 0) + amount_tr
            FROM customers
            WHERE customer_id = _customer_id);
END;
$$ LANGUAGE plpgsql;

SELECT part5_target_value_transaction(3, 16, 2);



CREATE OR REPLACE FUNCTION part5_offer_disc(_customer_id BIGINT, max_churn_index NUMERIC,
                                            max_discount_rate NUMERIC, margin NUMERIC) RETURNS NUMERIC AS
$$
DECLARE
    len     INTEGER = (SELECT count(*)
                       FROM groups
                       WHERE customer_id = _customer_id);
    i       INT     = 1;
    r       RECORD;
    _margin NUMERIC;
BEGIN
    FOR i IN 1..len
        LOOP
            SELECT group_margin, group_minimum_discount, group_id
            FROM groups
            WHERE customer_id = _customer_id
              AND group_churn_rate <= max_churn_index
              AND group_discount_share < max_discount_rate
            ORDER BY group_affinity_index DESC, group_id
            LIMIT 1 OFFSET i - 1
            INTO r;
            IF r.group_margin IS NOT NULL AND r.group_minimum_discount IS NOT NULL THEN
                _margin = avg(r.group_margin) * margin;
                IF _margin > ceil(r.group_minimum_discount / 5) * 5 THEN
                    RETURN ceil(r.group_minimum_discount / 5) * 5;
                END IF;
            END IF;
        END LOOP;
    RETURN 0;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION part5_group_name(_customer_id BIGINT, max_churn_index NUMERIC,
                                            max_discount_rate NUMERIC, margin NUMERIC) RETURNS VARCHAR AS
$$
DECLARE
    len     INTEGER = (SELECT count(*)
                       FROM groups
                       WHERE customer_id = _customer_id);
    i       INT     = 1;
    r       RECORD;
    _margin NUMERIC;
BEGIN
    FOR i IN 1..len
        LOOP
            SELECT group_margin, group_minimum_discount, group_id
            FROM groups
            WHERE customer_id = _customer_id
              AND group_churn_rate <= max_churn_index
              AND group_discount_share < max_discount_rate
            ORDER BY group_affinity_index DESC, group_id
            LIMIT 1 OFFSET i - 1
            INTO r;
            IF r.group_margin IS NOT NULL AND r.group_minimum_discount IS NOT NULL THEN
                _margin = r.group_margin * margin;
                IF _margin > ceil(r.group_minimum_discount / 5) * 5 THEN
                    RETURN (SELECT group_name FROM sku_group where group_id = r.group_id);
                END IF;
            END IF;
        END LOOP;
    RETURN 0;
END;
$$ LANGUAGE plpgsql;


SELECT *
FROM part5_increase_frequency('2022-08-18', '2022-08-18', 1, 3, 70, 30);