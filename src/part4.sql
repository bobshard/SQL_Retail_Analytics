CREATE OR REPLACE FUNCTION part4_average_check_1(_customer_id BIGINT, begin_date TIMESTAMP, finish_date TIMESTAMP,
                                                 c_average_check NUMERIC) RETURNS NUMERIC AS
$$
DECLARE
    date_of_analysis TIMESTAMP = (SELECT to_timestamp(analysis_formation, 'DD.MM.YYYY HH24:MI:SS')
                                  FROM date_of_analysis_formation);
    begin_of_period  TIMESTAMP = (SELECT min(to_timestamp(transaction_datetime, 'DD.MM.YYYY HH24:MI:SS'))
                                  FROM transactions t
                                           JOIN cards c ON t.customer_card_id = c.customer_card_id
                                  WHERE c.customer_id = _customer_id);
BEGIN
    IF begin_date < begin_of_period THEN
        begin_date = begin_of_period;
    END IF;
    IF date_of_analysis < finish_date THEN
        finish_date = date_of_analysis;
    END IF;
    RETURN (SELECT sum(transaction_summ) / count(transaction_id)
            FROM transactions t
                     JOIN cards c ON t.customer_card_id = c.customer_card_id
            WHERE c.customer_id = _customer_id
              AND to_timestamp(transaction_datetime, 'DD.MM.YYYY HH24:MI:SS')
                BETWEEN begin_date AND finish_date) * c_average_check;
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION part4_average_check_2(_customer_id BIGINT, count_transaction INT,
                                                 c_average_check NUMERIC) RETURNS NUMERIC AS
$$
BEGIN
    RETURN (WITH tr AS (SELECT *
                        from transactions
                                 JOIN cards c ON c.customer_card_id = transactions.customer_card_id
                        WHERE c.customer_id = _customer_id
                        ORDER BY to_timestamp(transaction_datetime, 'DD.MM.YYYY HH24:MI:SS') DESC
                        LIMIT count_transaction)
            SELECT sum(transaction_summ) / count(transaction_id)
            FROM tr) * c_average_check;
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION part4_discount(_customer_id BIGINT, max_churn_index NUMERIC,
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
                _margin = r.group_margin * margin;
                IF _margin > ceil((r.group_minimum_discount * 100 / 5) * 5) THEN
                    RETURN ceil(r.group_minimum_discount * 100 / 5) * 5;
                END IF;
            END IF;
        END LOOP;
    RETURN 0;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION part4_name(_customer_id BIGINT, max_churn_index NUMERIC,
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
                IF _margin > ceil((r.group_minimum_discount * 100 / 5) * 5) THEN
                    RETURN (SELECT group_name FROM sku_group where group_id = r.group_id);
                END IF;
            END IF;
        END LOOP;
    RETURN 0;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION part4_get_margin(met_average_check INTEGER,
                                            first_date_p DATE,
                                            last_date_p DATE,
                                            amount_tr INTEGER,
                                            c_aver_check NUMERIC,
                                            max_churn_rate NUMERIC,
                                            max_share_tr NUMERIC,
                                            ad_share_mar NUMERIC)
    RETURNS TABLE
            (
                customer_id            BIGINT,
                Required_Check_Measure NUMERIC,
                Group_Name             VARCHAR,
                Offer_Discount_Depth   NUMERIC
            )
AS
$$
DECLARE
    begin_datetime  TIMESTAMP = (SELECT first_date_p::timestamp);
    finish_datetime TIMESTAMP = (SELECT last_date_p::timestamp);
BEGIN
    IF met_average_check = 1 THEN
        RETURN QUERY (SELECT pe.customer_id,
                             part4_average_check_1(pe.customer_id, begin_datetime, finish_datetime, c_aver_check),
                             part4_name(pe.customer_id, max_churn_rate, max_share_tr::NUMERIC / 100,
                                        ad_share_mar::NUMERIC / 100),
                             part4_discount(pe.customer_id, max_churn_rate, max_share_tr::NUMERIC / 100,
                                            ad_share_mar::NUMERIC / 100)
                      FROM personal_information pe);
    ELSIF met_average_check = 2 THEN
        RETURN QUERY (SELECT pe.customer_id,
                             part4_average_check_2(pe.customer_id, amount_tr, c_aver_check),
                             part4_name(pe.customer_id, max_churn_rate, max_share_tr::NUMERIC / 100,
                                        ad_share_mar::NUMERIC / 100),
                             part4_discount(pe.customer_id, max_churn_rate, max_share_tr::NUMERIC / 100,
                                            ad_share_mar::NUMERIC / 100)
                      FROM personal_information pe);
    END IF;
END;
$$ LANGUAGE plpgsql;

SELECT *
FROM part4_get_margin(2, '2021-09-02', '2023-01-01', 100, 1.15, 3, 70, 30);
