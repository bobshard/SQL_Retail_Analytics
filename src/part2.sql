-- View Clients

CREATE OR REPLACE FUNCTION part2_get_cards_by_id(id BIGINT)
    RETURNS TABLE
            (
                card_id BIGINT
            )
AS
$$
BEGIN
    RETURN QUERY
        SELECT customer_card_id
        FROM cards
        WHERE customer_id = id;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION part2_get_average_check_by_id(id BIGINT) RETURNS NUMERIC AS
$$
DECLARE
    result NUMERIC;
BEGIN
    result = (SELECT avg(transaction_summ)
              FROM transactions
              WHERE customer_card_id IN (SELECT part2_get_cards_by_id(id)));
    IF result IS NOT NULL THEN
        RETURN result;
    END IF;
    RETURN 0;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION part2_segment_average_check(id BIGINT) RETURNS VARCHAR AS
$$
DECLARE
    count_customers INTEGER = (SELECT count(customer_id)
                               FROM personal_information);
    high_segment    INTEGER = count_customers * 0.1;
    medium_segment  INTEGER = count_customers * 0.35;
BEGIN
    IF id IN (SELECT customer_id FROM part2_view_average_check LIMIT high_segment) THEN
        RETURN 'High';
    ELSEIF id IN (SELECT customer_id FROM part2_view_average_check LIMIT medium_segment) THEN
        RETURN 'Medium';
    ELSE
        RETURN 'Low';
    END IF;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION part2_decision_segment_by_id(id BIGINT) RETURNS VARCHAR AS
$$
BEGIN
    RETURN (SELECT average_check_segment FROM part2_view_common WHERE customer_id = id);
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION part2_intensive_transaction(_id BIGINT) RETURNS NUMERIC AS
$$
DECLARE
    max_date              DATE   = (SELECT max(to_timestamp(transaction_datetime, 'DD.MM.YYYY HH24:MI:SS'))
                                    FROM cards c
                                             JOIN transactions t on c.customer_card_id = t.customer_card_id
                                    where c.customer_id = _id);
    min_date              DATE   = (SELECT min(to_timestamp(transaction_datetime, 'DD.MM.YYYY HH24:MI:SS'))
                                    FROM cards c
                                             JOIN transactions t on c.customer_card_id = t.customer_card_id
                                    where c.customer_id = _id);
    intensive_transaction NUMERIC;
    amount_transact       BIGINT = (SELECT count(transaction_id)
                                    FROM transactions
                                    WHERE customer_card_id IN (SELECT * FROM part2_get_cards_by_id(_id)));
BEGIN
    IF amount_transact != 0 THEN
        intensive_transaction = (max_date - min_date)::NUMERIC / amount_transact;
        IF intensive_transaction IS NOT NULL THEN
            RETURN intensive_transaction;
        END IF;
    END IF;
    RETURN 0;
END;
$$ LANGUAGE plpgsql;


CREATE MATERIALIZED VIEW IF NOT EXISTS part2_view_intensive_transaction AS
SELECT customer_id,
       part2_intensive_transaction(customer_id) AS intensive_transaction
FROM personal_information
ORDER BY intensive_transaction;


CREATE OR REPLACE FUNCTION part2_intensive_segment_by_id(id BIGINT) RETURNS VARCHAR AS
$$
DECLARE
    count_customers INTEGER = (SELECT count(customer_id)
                               FROM personal_information);
    high_segment    INTEGER = count_customers * 0.1;
    medium_segment  INTEGER = count_customers * 0.35;
BEGIN
    IF id IN (SELECT customer_id FROM part2_view_intensive_transaction LIMIT high_segment) THEN
        RETURN 'Often';
    ELSEIF id IN (SELECT customer_id FROM part2_view_intensive_transaction LIMIT medium_segment) THEN
        RETURN 'Occasionally';
    ELSE
        RETURN 'Rarely';
    END IF;
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION part2_get_day_inactive_by_id(id BIGINT) RETURNS NUMERIC AS
$$
DECLARE
    date_of_analysis TIMESTAMP = (SELECT to_timestamp(analysis_formation, 'DD.MM.YYYY HH24:MI:SS')
                                  FROM date_of_analysis_formation);
    date_last_order  TIMESTAMP = (SELECT to_timestamp(transaction_datetime, 'DD.MM.YYYY HH24:MI:SS') AS datetime
                                  FROM transactions
                                  WHERE customer_card_id IN (SELECT part2_get_cards_by_id(id))
                                    AND to_timestamp(transaction_datetime, 'DD.MM.YYYY HH24:MI:SS') < date_of_analysis
                                  ORDER BY datetime DESC
                                  LIMIT 1);
BEGIN
    RETURN (extract(epoch FROM date_of_analysis) - extract(epoch FROM date_last_order)) / (60 * 60 * 24)::NUMERIC;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION part2_calculate_churn_rate_by_id(id BIGINT) RETURNS NUMERIC AS
$$
BEGIN
    RETURN (SELECT day_inactive FROM part2_view_common WHERE customer_id = id) /
           (SELECT intensive_transaction FROM part2_view_intensive_transaction WHERE customer_id = id);
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION part2_decision_churn_segment(id BIGINT) RETURNS VARCHAR AS
$$
DECLARE
    churn_rank NUMERIC = part2_calculate_churn_rate_by_id(id);
BEGIN
    IF churn_rank >= 0 AND churn_rank <= 2 THEN
        RETURN 'Low';
    ELSEIF churn_rank > 2 AND churn_rank <= 5 THEN
        RETURN 'Medium';
    ELSE
        RETURN 'High';
    END IF;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION part2_generate_segment_table(check_average_check VARCHAR, check_frequency VARCHAR,
                                                        check_churn VARCHAR) RETURNS INTEGER AS
$$
DECLARE
    average_check_segment VARCHAR[] = ARRAY ['Low', 'Medium', 'High'];
    frequency_segment     VARCHAR[] = ARRAY ['Rarely', 'Occasionally', 'Often'];
    churn_segment         VARCHAR[] = ARRAY ['Low', 'Medium', 'High'];
    segment_number        INTEGER   = 1;
    current_average_check VARCHAR;
    current_frequency     VARCHAR;
    current_churn         VARCHAR;
BEGIN
    FOREACH current_average_check IN ARRAY average_check_segment
        LOOP
            FOREACH current_frequency IN ARRAY frequency_segment
                LOOP
                    FOREACH current_churn IN ARRAY churn_segment
                        LOOP
                            IF check_average_check = current_average_check AND
                               check_frequency = current_frequency AND
                               check_churn = current_churn THEN
                                RETURN segment_number;
                            END IF;
                            segment_number = segment_number + 1;
                        END LOOP;
                END LOOP;
        END LOOP;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION part2_get_segment_number(id BIGINT) RETURNS INTEGER AS
$$
BEGIN
    RETURN part2_generate_segment_table(part2_decision_segment_by_id(id),
                                        part2_intensive_segment_by_id(id),
                                        part2_decision_churn_segment(id));
END;
$$ LANGUAGE plpgsql;

CREATE MATERIALIZED VIEW IF NOT EXISTS part2_view_average_check AS
SELECT customer_id,
       part2_get_average_check_by_id(customer_id) AS averge_check
FROM personal_information
ORDER BY averge_check DESC;
CREATE INDEX idx_av_ch ON part2_view_average_check (customer_id, averge_check);

CREATE MATERIALIZED VIEW IF NOT EXISTS part2_view_average_check_segment AS
SELECT customer_id,
       part2_segment_average_check(customer_id) AS segment
FROM personal_information;
CREATE INDEX idx_av_ch_seg ON part2_view_average_check_segment (customer_id, segment);

CREATE MATERIALIZED VIEW IF NOT EXISTS part2_view_common AS
SELECT customer_id,
       part2_get_day_inactive_by_id(customer_id) AS day_inactive,
       part2_segment_average_check(customer_id)  AS average_check_segment
FROM personal_information;
CREATE INDEX idx_com ON part2_view_common (customer_id, average_check_segment);

CREATE MATERIALIZED VIEW IF NOT EXISTS part2_view_intensive_transaction AS
SELECT customer_id,
       part2_intensive_transaction(customer_id) AS intensive_transaction
FROM personal_information
ORDER BY intensive_transaction DESC;

CREATE MATERIALIZED VIEW IF NOT EXISTS part2_view_churn_segment AS
SELECT customer_id,
       part2_decision_churn_segment(customer_id) AS segment
FROM personal_information;

CREATE MATERIALIZED VIEW IF NOT EXISTS share_tran AS
SELECT customer_id, transaction_store_id, share, count(share) OVER (PARTITION BY customer_id,share) AS count_share
FROM (SELECT DISTINCT personal_information.customer_id,
                      t.transaction_store_id,
                      (count(t.transaction_id) OVER (PARTITION BY transaction_store_id) /
                       NULLIF(count(transaction_id) OVER (PARTITION BY personal_information.customer_id), 0)) AS share
      FROM personal_information
               LEFT JOIN cards c ON personal_information.customer_id = c.customer_id
               LEFT JOIN transactions t ON c.customer_card_id = t.customer_card_id
      WHERE to_timestamp(transaction_datetime, 'DD-MM-YYYY')::DATE <
            (SELECT to_timestamp(analysis_formation, 'DD-MM-YYYY') FROM date_of_analysis_formation)
      ORDER BY 1, 2) AS tmp;
CREATE INDEX idx_share_tran ON share_tran (customer_id, transaction_store_id, share);

CREATE MATERIALIZED VIEW IF NOT EXISTS last_three_tran AS
SELECT customer_id,
       transaction_datetime,
       transaction_store_id,
       tmp,
       (count(transaction_store_id) OVER (PARTITION BY customer_id,transaction_store_id)) AS uniq_st
FROM (SELECT DISTINCT personal_information.customer_id,
                      to_timestamp(t.transaction_datetime, 'DD.MM.YYYY HH24:MI:SS')::TIMESTAMP                                                                      AS transaction_datetime,
                      transaction_store_id,
                      (row_number()
                       OVER (PARTITION BY personal_information.customer_id ORDER BY to_timestamp(t.transaction_datetime, 'DD.MM.YYYY HH24:MI:SS')::TIMESTAMP DESC)) AS tmp
      FROM personal_information
               LEFT JOIN cards c ON personal_information.customer_id = c.customer_id
               LEFT JOIN transactions t ON c.customer_card_id = t.customer_card_id
      WHERE to_timestamp(transaction_datetime, 'DD-MM-YYYY')::DATE <
            (SELECT to_timestamp(analysis_formation, 'DD-MM-YYYY') FROM date_of_analysis_formation)
      ORDER BY 1, 4 DESC) AS t
WHERE tmp <= 3;
CREATE INDEX ind_last_three_tran ON last_three_tran (customer_id, transaction_datetime, transaction_store_id);

CREATE OR REPLACE FUNCTION part2_customer_primary_store(_customer_id BIGINT)
    RETURNS BIGINT
AS
$$
BEGIN
    RETURN (SELECT CASE
                       WHEN max(uniq_st) != 3 THEN (SELECT CASE
                                                               WHEN max(count_share) > 1
                                                                   THEN (SELECT last_three_tran.transaction_store_id
                                                                         FROM last_three_tran
                                                                         WHERE tmp = 1
                                                                           AND last_three_tran.customer_id = _customer_id)
                                                               ELSE (SELECT transaction_store_id
                                                                     FROM share_tran
                                                                     WHERE share_tran.customer_id = _customer_id
                                                                     ORDER BY share DESC
                                                                     LIMIT 1) END
                                                    FROM share_tran
                                                    WHERE share_tran.customer_id = _customer_id)
                       ELSE min(uniq_st) END
            FROM last_three_tran
            WHERE customer_id = _customer_id);
END;
$$ LANGUAGE plpgsql;

CREATE MATERIALIZED VIEW customers AS
SELECT customer_id,
       part2_get_average_check_by_id(customer_id)    Customer_Average_Check,
       part2_decision_segment_by_id(customer_id)     Customer_Average_Check_Segment,
       part2_intensive_transaction(customer_id)      Customer_Frequency,
       part2_intensive_segment_by_id(customer_id)    Customer_Frequency_Segment,
       part2_get_day_inactive_by_id(customer_id)     Customer_Inactive_Period,
       part2_calculate_churn_rate_by_id(customer_id) Customer_Churn_Rate,
       part2_decision_churn_segment(customer_id)     Customer_Churn_Segment,
       part2_get_segment_number(customer_id)         Customer_Segment,
       part2_customer_primary_store(customer_id)     Customer_Primary_Store
FROM personal_information;

CREATE INDEX idx_customers ON customers (customer_id, Customer_Primary_Store);


CREATE MATERIALIZED VIEW purchase_history AS
SELECT c.customer_id,
       ch.transaction_id,
       to_timestamp(t.transaction_datetime, 'DD.MM.YYYY HH24:MI:SS')::TIMESTAMP AS transaction_datetime,
       group_id,
       sum(sku_purchase_price * sku_amount)                                     AS group_cost,
       sum(sku_summ)                                                            AS group_summ,
       sum(sku_summ_paid)                                                       AS group_summ_paid
FROM cards c
         JOIN transactions t ON c.customer_card_id = t.customer_card_id
         JOIN checks ch ON t.transaction_id = ch.transaction_id
         JOIN product_grid pg ON ch.sku_id = pg.sku_id
         JOIN stores s ON pg.sku_id = s.sku_id AND s.transaction_store_id = t.transaction_store_id
WHERE (SELECT to_timestamp(analysis_formation, 'DD.MM.YYYY HH24:MI:SS')::TIMESTAMP FROM date_of_analysis_formation) >=
      to_timestamp(t.transaction_datetime, 'DD.MM.YYYY HH24:MI:SS')::TIMESTAMP
GROUP BY c.customer_id, ch.transaction_id, t.transaction_datetime, group_id
ORDER BY customer_id, group_id, transaction_id;


SELECT DISTINCT customer_id, group_id, c.transaction_id, transaction_datetime, sum(sku_summ_paid), sum(sku_summ)
FROM cards
         JOIN transactions t on cards.customer_card_id = t.customer_card_id
         JOIN checks c on t.transaction_id = c.transaction_id
         JOIN product_grid pg on c.sku_id = pg.sku_id
         JOIN stores s on pg.sku_id = s.sku_id AND s.transaction_store_id = t.transaction_store_id
GROUP BY 1, 2, 3, 4
ORDER BY 1, 2;

CREATE OR REPLACE VIEW view_min_discount AS
SELECT checks.transaction_id, group_id, min(sku_summ_discount / sku_summ) AS min_disc
FROM checks
         JOIN product_grid pg ON pg.sku_id = checks.sku_id
WHERE sku_summ_discount > 0
GROUP BY checks.transaction_id, group_id
ORDER BY 2, 3;

CREATE OR REPLACE VIEW view_min_discount_with_purchase_history AS
SELECT purchase_history.group_id, min_disc, purchase_history.transaction_id
FROM purchase_history
         LEFT JOIN view_min_discount vmd
                   ON purchase_history.group_id = vmd.group_id AND purchase_history.transaction_id = vmd.transaction_id;

CREATE MATERIALIZED VIEW periods AS
SELECT DISTINCT customer_id,
                purchase_history.group_id                AS group_id,
                min(transaction_datetime)                AS first_group_purchase_date,
                max(transaction_datetime)                AS last_group_purchase_date,
                count(purchase_history.transaction_id)   AS group_purchase,
                (((max(transaction_datetime))::DATE -
                  (min(transaction_datetime))::DATE)::NUMERIC + 1) /
                (count(purchase_history.transaction_id)) AS group_frequency,
                coalesce(min(min_disc), 0)               AS group_min_discount
FROM purchase_history
         LEFT JOIN view_min_discount_with_purchase_history tmp
                   ON purchase_history.group_id = tmp.group_id AND purchase_history.transaction_id = tmp.transaction_id
WHERE (SELECT to_timestamp(analysis_formation, 'DD.MM.YYYY HH24:MI:SS')::TIMESTAMP FROM date_of_analysis_formation) >=
      transaction_datetime
GROUP BY purchase_history.customer_id, purchase_history.group_id
ORDER BY purchase_history.customer_id, group_id;


CREATE OR REPLACE FUNCTION part2_affine_ind(_customer_id BIGINT, _group_id BIGINT)
    RETURNS NUMERIC
AS
$$
DECLARE
    affine_ind NUMERIC = (SELECT group_purchase::NUMERIC / (SELECT count(DISTINCT transaction_id)
                                                            FROM purchase_history
                                                            WHERE purchase_history.customer_id = _customer_id
                                                              AND transaction_datetime BETWEEN first_group_purchase_date AND last_group_purchase_date)
                          FROM periods
                          WHERE periods.customer_id = _customer_id
                            AND periods.group_id = _group_id);
BEGIN
    RETURN affine_ind;
END;
$$ LANGUAGE plpgsql;

CREATE INDEX pur_idx ON purchase_history (customer_id, group_id, transaction_id, transaction_datetime);
CREATE INDEX per_idx ON periods (customer_id, group_id, first_group_purchase_date, last_group_purchase_date,
                                 group_purchase, group_frequency, group_min_discount);

CREATE OR REPLACE FUNCTION part2_churn_rate(_customer_id BIGINT, _group_id BIGINT)
    RETURNS NUMERIC
AS
$$
DECLARE
    churn_rate NUMERIC = (SELECT DISTINCT ((SELECT to_timestamp(analysis_formation, 'DD.MM.YYYY HH24:MI:SS')::DATE
                                            FROM date_of_analysis_formation) -
                                           (max(transaction_datetime)
                                            OVER (PARTITION BY purchase_history.customer_id,purchase_history.group_id))::DATE) /
                                          avg(group_frequency)
                                          OVER (PARTITION BY purchase_history.customer_id,purchase_history.group_id)
                          FROM purchase_history
                                   LEFT JOIN periods p ON purchase_history.customer_id = p.customer_id AND
                                                          p.group_id = purchase_history.group_id
                          WHERE p.customer_id = _customer_id
                            AND p.group_id = _group_id);
BEGIN
    RETURN churn_rate ;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION part2_group_stability_index(_customer_id BIGINT, _group_id BIGINT)
    RETURNS NUMERIC
AS
$$
BEGIN
    RETURN (WITH t1 AS (SELECT DISTINCT (CASE
                                             WHEN (coalesce(lead(transaction_datetime::DATE)
                                                            OVER (PARTITION BY purchase_history.customer_id,purchase_history.group_id) -
                                                            transaction_datetime::DATE, 0) -
                                                   (p.group_frequency)
                                                      ) < 0 THEN
                                                     ((coalesce(lead(
                                                                transaction_datetime::DATE)
                                                                OVER (PARTITION BY purchase_history.customer_id,purchase_history.group_id) -
                                                                transaction_datetime::DATE,
                                                                0) - (p.group_frequency)
                                                          ) * -1) / (group_frequency)
                                             ELSE (coalesce(lead(transaction_datetime::DATE)
                                                            OVER (PARTITION BY purchase_history.customer_id,purchase_history.group_id) -
                                                            transaction_datetime::DATE, 0) -
                                                   (p.group_frequency)) /
                                                  (group_frequency) END) AS tmp
                        FROM (SELECT * FROM purchase_history ORDER BY transaction_datetime) purchase_history
                                 LEFT JOIN periods p
                                           ON purchase_history.customer_id = p.customer_id AND
                                              p.group_id = purchase_history.group_id
                        WHERE purchase_history.customer_id = _customer_id
                          AND purchase_history.group_id = _group_id)
            SELECT avg(t1.tmp)
            FROM t1);
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION part2_churn_rate(_customer_id BIGINT, _group_id BIGINT)
    RETURNS NUMERIC
AS
$$
DECLARE
    churn_rate NUMERIC = (SELECT (SELECT (SELECT to_timestamp(analysis_formation, 'DD.MM.YYYY HH24:MI:SS')::DATE
                                          FROM date_of_analysis_formation) -
                                         max(transaction_datetime)::DATE
                                  FROM purchase_history
                                  WHERE purchase_history.customer_id = _customer_id
                                    AND purchase_history.group_id = _group_id) / group_frequency
                          FROM periods
                          WHERE periods.customer_id = _customer_id
                            AND periods.group_id = _group_id);
BEGIN
    RETURN churn_rate ;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION part2_get_margin(_customer_id BIGINT, _group_id BIGINT, amount BIGINT, num_met INTEGER)
    RETURNS NUMERIC
AS
$$
DECLARE
    date_of_analysis TIMESTAMP = (SELECT to_timestamp(analysis_formation, 'DD.MM.YYYY HH24:MI:SS')
                                  FROM date_of_analysis_formation);
    date_period      TIMESTAMP = date_of_analysis::DATE - amount::INTEGER;
BEGIN

    IF num_met = 2 THEN
        RETURN (SELECT DISTINCT sum(group_summ_paid - group_cost)
                                OVER (PARTITION BY tmp.customer_id,tmp.group_id) AS group_margin
                FROM (SELECT *,
                             (row_number()
                              OVER (PARTITION BY purchase_history.customer_id,purchase_history.group_id ORDER BY transaction_datetime DESC)) AS amount_tran
                      FROM purchase_history) AS tmp
                WHERE date_of_analysis >= transaction_datetime
                  AND customer_id = _customer_id
                  AND group_id = _group_id
                  AND amount_tran <= amount);
    ELSIF num_met = 1 THEN
        RETURN (SELECT DISTINCT sum(group_summ_paid - group_cost)
                                OVER (PARTITION BY purchase_history.customer_id,purchase_history.group_id) AS group_margin
                FROM purchase_history
                WHERE date_of_analysis >= transaction_datetime
                  AND date_period <= transaction_datetime::DATE
                  AND customer_id = _customer_id
                  AND group_id = _group_id);
    ELSE
        RETURN (SELECT DISTINCT sum(group_summ_paid - group_cost)
                                OVER (PARTITION BY purchase_history.customer_id,purchase_history.group_id) AS group_margin
                FROM purchase_history
                WHERE date_of_analysis >= purchase_history.transaction_datetime
                  AND customer_id = _customer_id
                  AND group_id = _group_id);
    END IF;

END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION part2_group_discount_share(_customer_id BIGINT, _group_id BIGINT)
    RETURNS NUMERIC
AS
$$
BEGIN
    RETURN (SELECT (SELECT tmp
                    FROM for_15_task f
                    WHERE f.customer_id = _customer_id
                      AND f.group_id = _group_id)::NUMERIC /
                   p.group_purchase
            FROM periods p
            WHERE p.group_id = _group_id
              AND p.customer_id = _customer_id);

END;
$$ LANGUAGE plpgsql;

CREATE MATERIALIZED VIEW for_15_task AS
SELECT personal_information.customer_id, group_id, count(DISTINCT transactions.transaction_id) AS tmp
FROM personal_information
         LEFT JOIN cards ON personal_information.customer_id = cards.customer_id
         LEFT JOIN transactions ON cards.customer_card_id = transactions.customer_card_id
         LEFT JOIN checks ON transactions.transaction_id = checks.transaction_id
         LEFT JOIN product_grid pg ON checks.sku_id = pg.sku_id
WHERE sku_summ_discount > 0
GROUP BY 1, 2;
CREATE INDEX ind_for_15_task ON for_15_task (customer_id, group_id, tmp);


CREATE OR REPLACE FUNCTION part2_group_minimum_discount(_customer_id BIGINT, _group_id BIGINT)
    RETURNS NUMERIC
AS
$$
BEGIN
    RETURN (SELECT min(group_min_discount)
            FROM periods
            WHERE group_min_discount > 0
              AND customer_id = _customer_id
              AND group_id = _group_id);

END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION part2_group_average_discount(_customer_id BIGINT, _group_id BIGINT)
    RETURNS NUMERIC
AS
$$
BEGIN
    RETURN (SELECT avg(purchase_history.group_summ_paid) / avg(group_summ)
            FROM purchase_history
            WHERE customer_id = _customer_id
              AND group_id = _group_id
            GROUP BY customer_id, group_id);
END;
$$ LANGUAGE plpgsql;

CREATE MATERIALIZED VIEW groups AS
SELECT personal_information.customer_id                                         AS customer_id,
       group_id,
       part2_affine_ind(personal_information.customer_id, group_id)             AS Group_Affinity_Index,
       part2_churn_rate(personal_information.customer_id, group_id)             AS Group_Churn_Rate,
       part2_group_stability_index(personal_information.customer_id, group_id)  AS Group_Stability_Index,
       part2_get_margin(personal_information.customer_id, group_id, 0, 0)       AS Group_Margin,
       part2_group_discount_share(personal_information.customer_id, group_id)   AS Group_Discount_Share,
       part2_group_minimum_discount(personal_information.customer_id, group_id) AS Group_Minimum_Discount,
       part2_group_average_discount(personal_information.customer_id, group_id) AS Group_Average_Discount
FROM personal_information
         LEFT JOIN cards c ON personal_information.customer_id = c.customer_id
         LEFT JOIN transactions t ON c.customer_card_id = t.customer_card_id
         LEFT JOIN checks c2 ON t.transaction_id = c2.transaction_id
         LEFT JOIN product_grid pg ON pg.sku_id = c2.sku_id
WHERE to_timestamp(t.transaction_datetime, 'DD.MM.YYYY HH24:MI:SS') <=
      (SELECT to_timestamp(analysis_formation, 'DD.MM.YYYY HH24:MI:SS')
       FROM date_of_analysis_formation)
GROUP BY personal_information.customer_id, group_id
ORDER BY 1, 2;

CREATE INDEX idx_groups ON groups (customer_id, group_id, group_affinity_index,
                                   group_churn_rate, group_margin, group_discount_share, group_minimum_discount);

SELECT *
FROM customers
WHERE customer_id = 1;

SELECT *
FROM purchase_history
WHERE customer_id = 1
  AND group_id = 2;

SELECT *
FROM periods
WHERE customer_id = 1
  AND group_id = 2;

SELECT *
FROM groups
WHERE customer_id = 1
  AND group_id = 3;


--

SELECT p.customer_id, sum(transaction_summ), count(p.customer_id)
FROM personal_information p
         JOIN cards c on p.customer_id = c.customer_id
         JOIN transactions t on c.customer_card_id = t.customer_card_id
group by p.customer_id;

Select to_timestamp(transaction_datetime, 'DD.MM.YYYY HH24:MI:SS')
from transactions;


