CREATE OR REPLACE FUNCTION part_6(count_of_group INTEGER, max_churn_rate NUMERIC, max_stability_index NUMERIC,
                                  max_rate_SKU NUMERIC, max_margin_rate NUMERIC)
    RETURNS TABLE
            (
                customer_id_         BIGINT,
                sku_name_            VARCHAR,
                offer_discount_depth NUMERIC
            )
AS
$$
BEGIN
    RETURN QUERY
        (WITH a AS (SELECT customer_id,
                           group_id,
                           row_number() OVER (PARTITION BY customer_id) AS row_number,
                           group_minimum_discount
                    FROM groups
                    WHERE group_churn_rate <= max_churn_rate
                      AND group_stability_index < max_stability_index
                    ORDER BY group_affinity_index DESC),
              b AS (SELECT customer_id, group_id, group_minimum_discount
                    FROM a
                    WHERE row_number < count_of_group),
              c AS (SELECT DISTINCT customer_id,
                                    b.group_id,
                                    pg.sku_id,
                                    sku_name,
                                    sku_retail_price - sku_purchase_price AS delta,
                                    sku_retail_price,
                                    customer_primary_store,
                                    group_minimum_discount
                    FROM b
                             JOIN (SELECT customer_id AS ci, customer_primary_store FROM customers) AS tt
                                  ON ci = customer_id
                             JOIN product_grid pg ON pg.group_id = b.group_id
                             JOIN stores s ON pg.sku_id = s.sku_id),
              d AS (SELECT customer_id,
                           group_id,
                           sku_id,
                           sku_name,
                           delta,
                           customer_primary_store,
                           group_minimum_discount,
                           sku_retail_price,
                           rank()
                           OVER (PARTITION BY customer_id,group_id,customer_primary_store ORDER BY delta DESC) AS rank
                    FROM c),
              e AS (SELECT customer_id,
                           group_id,
                           sku_id,
                           sku_name,
                           delta,
                           customer_primary_store,
                           sku_retail_price,
                           group_minimum_discount
                    FROM d
                    WHERE rank < 2),

              f AS (SELECT DISTINCT customer_id,
                                    group_id,
                                    e.sku_id,
                                    sku_name,
                                    delta,
                                    customer_primary_store,
                                    transaction_id,
                                    sku_retail_price,
                                    group_minimum_discount,
                                    (c_ts::NUMERIC / c_tg) * 100 AS value
                    FROM e
                             JOIN checks c ON e.sku_id = c.sku_id
                             LEFT JOIN (SELECT count(transaction_id) AS c_ts,
                                               sku_id                AS c_s
                                        FROM checks
                                        group by sku_id) AS ff ON e.sku_id = ff.c_s
                             LEFT JOIN (SELECT group_id                 c_g,
                                               count(transaction_id) AS c_tg
                                        FROM checks
                                                 JOIN product_grid p ON checks.sku_id = p.sku_id
                                        GROUP BY group_id) AS fff ON group_id = fff.c_g
                    ORDER BY 1, 2),
              g AS (SELECT customer_id,
                           sku_name,
                           delta * max_margin_rate / sku_retail_price          AS tttmp,
                           ceil(group_minimum_discount::NUMERIC * 100 / 5) * 5 AS disc
                    FROM f
                    WHERE value <= max_rate_SKU),
              h AS (SELECT DISTINCT customer_id,
                                    sku_name,
                                    disc
                    FROM g
                    WHERE tttmp * 100 >= disc)
         SELECT *
         FROM h);
END;
$$ LANGUAGE plpgsql;

SELECT *
FROM part_6(5, 3, 0.5, 100, 30);