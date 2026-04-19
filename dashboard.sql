
-- ОСНОВНОЙ ДАТАСЕТ

SELECT
    alpc.visit_date,
    alpc.utm_source,
    alpc.utm_medium,
    alpc.utm_campaign,
    alpc.visitors_count,
    alpc.leads_count,
    alpc.purchases_count,
    alpc.revenue,
    alpc.total_cost,
    ROUND(
        alpc.total_cost::numeric / NULLIF(alpc.visitors_count, 0),
        2
    ) AS cpu,
    ROUND(
        alpc.total_cost::numeric / NULLIF(alpc.leads_count, 0),
        2
    ) AS cpl,
    ROUND(
        alpc.total_cost::numeric / NULLIF(alpc.purchases_count, 0),
        2
    ) AS cppu,
    ROUND(
        (
            alpc.revenue - COALESCE(alpc.total_cost, 0)
        )::numeric / NULLIF(alpc.total_cost, 0) * 100,
        2
    ) AS roi
FROM aggregate_last_paid_click AS alpc
ORDER BY
    roi DESC NULLS LAST,
    alpc.visit_date ASC,
    alpc.utm_source ASC,
    alpc.utm_medium ASC,
    alpc.utm_campaign ASC;

-- АНАЛИЗ ОКУПАЕМОСТИ КАНАЛОВ

SELECT
    alpc.utm_source,
    alpc.utm_medium,
    alpc.utm_campaign,
    SUM(alpc.visitors_count) AS visitors_count,
    SUM(alpc.leads_count) AS leads_count,
    SUM(alpc.purchases_count) AS purchases_count,
    SUM(alpc.revenue) AS revenue,
    SUM(alpc.total_cost) AS total_cost,
    ROUND(
        SUM(alpc.total_cost)::numeric / NULLIF(SUM(alpc.visitors_count), 0),
        2
    ) AS cpu,
    ROUND(
        SUM(alpc.total_cost)::numeric / NULLIF(SUM(alpc.leads_count), 0),
        2
    ) AS cpl,
    ROUND(
        SUM(alpc.total_cost)::numeric / NULLIF(SUM(alpc.purchases_count), 0),
        2
    ) AS cppu,
    ROUND(
        (
            SUM(alpc.revenue) - COALESCE(SUM(alpc.total_cost), 0)
        )::numeric / NULLIF(SUM(alpc.total_cost), 0) * 100,
        2
    ) AS roi
FROM aggregate_last_paid_click AS alpc
GROUP BY
    alpc.utm_source,
    alpc.utm_medium,
    alpc.utm_campaign
ORDER BY
    roi DESC NULLS LAST,
    revenue DESC,
    alpc.utm_source ASC,
    alpc.utm_medium ASC,
    alpc.utm_campaign ASC;


-- СРОК, ЗА КОТОРЫЙ ЗАКРЫВАЕТСЯ 90% ЛИДОВ ПОСЛЕ ПЕРЕХОДА ПО РЕКЛАМЕ

WITH last_paid_click AS (
    SELECT DISTINCT ON (s.visitor_id)
        s.visitor_id,
        s.visit_date AS visit_datetime
    FROM sessions AS s
    WHERE LOWER(s.medium) != 'organic'
    ORDER BY
        s.visitor_id ASC,
        s.visit_date DESC
),

first_lead_after_click AS (
    SELECT DISTINCT ON (lpc.visitor_id)
        lpc.visitor_id,
        l.created_at,
        EXTRACT(
            EPOCH FROM (l.created_at - lpc.visit_datetime)
        ) / 86400 AS days_to_close
    FROM last_paid_click AS lpc
    LEFT JOIN leads AS l
        ON
            lpc.visitor_id = l.visitor_id
            AND lpc.visit_datetime <= l.created_at
    WHERE l.lead_id IS NOT NULL
    ORDER BY
        lpc.visitor_id ASC,
        l.created_at ASC,
        l.lead_id ASC
)

SELECT
    ROUND(
        PERCENTILE_CONT(0.9) WITHIN GROUP (
            ORDER BY flac.days_to_close ASC
        )::numeric,
        2
    ) AS days_to_close_90_percent
FROM first_lead_after_click AS flac;


-- ДИНАМИКА ОРГАНИЧЕСКОГО ТРАФИКА

SELECT
    s.visit_date::date AS visit_date,
    COUNT(DISTINCT s.visitor_id) AS organic_visitors_count
FROM sessions AS s
WHERE LOWER(s.medium) = 'organic'
GROUP BY
    s.visit_date::date
ORDER BY
    visit_date ASC;


-- СРАВНЕНИЕ ПЛАТНОГО И ОРГАНИЧЕСКОГО ТРАФИКА ПО ДНЯМ

WITH paid_traffic AS (
    SELECT
        s.visit_date::date AS visit_date,
        COUNT(DISTINCT s.visitor_id) AS paid_visitors_count
    FROM sessions AS s
    WHERE LOWER(s.medium) != 'organic'
    GROUP BY
        s.visit_date::date
),

organic_traffic AS (
    SELECT
        s.visit_date::date AS visit_date,
        COUNT(DISTINCT s.visitor_id) AS organic_visitors_count
    FROM sessions AS s
    WHERE LOWER(s.medium) = 'organic'
    GROUP BY
        s.visit_date::date
)

SELECT
    COALESCE(pt.visit_date, ot.visit_date) AS visit_date,
    COALESCE(pt.paid_visitors_count, 0) AS paid_visitors_count,
    COALESCE(ot.organic_visitors_count, 0) AS organic_visitors_count
FROM paid_traffic AS pt
FULL OUTER JOIN organic_traffic AS ot
    ON pt.visit_date = ot.visit_date
ORDER BY
    visit_date ASC;
