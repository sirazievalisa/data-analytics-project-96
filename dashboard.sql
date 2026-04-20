-- ОСНОВНОЙ ДАТАСЕТ

WITH last_paid_click AS (
    SELECT DISTINCT ON (s.visitor_id)
        s.visitor_id,
        s.visit_date::date AS visit_date,
        s.visit_date AS visit_datetime,
        s.source AS utm_source,
        s.medium AS utm_medium,
        s.campaign AS utm_campaign
    FROM sessions AS s
    WHERE LOWER(s.medium) != 'organic'
    ORDER BY
        s.visitor_id ASC,
        s.visit_date DESC,
        s.source ASC,
        s.medium ASC,
        s.campaign ASC
),

first_lead_after_click AS (
    SELECT DISTINCT ON (lpc.visitor_id)
        lpc.visitor_id,
        lpc.visit_date,
        lpc.utm_source,
        lpc.utm_medium,
        lpc.utm_campaign,
        l.lead_id,
        l.created_at,
        l.amount,
        l.closing_reason,
        l.status_id
    FROM last_paid_click AS lpc
    LEFT JOIN leads AS l
        ON
            lpc.visitor_id = l.visitor_id
            AND lpc.visit_datetime <= l.created_at
    ORDER BY
        lpc.visitor_id ASC,
        l.created_at ASC NULLS LAST,
        l.lead_id ASC
),

costs_agg AS (
    SELECT
        ads.campaign_date::date AS visit_date,
        ads.utm_source,
        ads.utm_medium,
        ads.utm_campaign,
        SUM(ads.daily_spent) AS total_cost
    FROM (
        SELECT
            vk.campaign_date,
            vk.utm_source,
            vk.utm_medium,
            vk.utm_campaign,
            vk.daily_spent
        FROM vk_ads AS vk

        UNION ALL

        SELECT
            ya.campaign_date,
            ya.utm_source,
            ya.utm_medium,
            ya.utm_campaign,
            ya.daily_spent
        FROM ya_ads AS ya
    ) AS ads
    GROUP BY
        ads.campaign_date::date,
        ads.utm_source,
        ads.utm_medium,
        ads.utm_campaign
),

aggregate_last_paid_click AS (
    SELECT
        lpc.visit_date,
        lpc.utm_source,
        lpc.utm_medium,
        lpc.utm_campaign,
        ca.total_cost,
        COUNT(*) AS visitors_count,
        COUNT(flac.lead_id) AS leads_count,
        COUNT(
            CASE
                WHEN
                    flac.closing_reason = 'Успешно реализовано'
                    OR flac.status_id = 142
                    THEN 1
            END
        ) AS purchases_count,
        SUM(
            CASE
                WHEN
                    flac.closing_reason = 'Успешно реализовано'
                    OR flac.status_id = 142
                    THEN flac.amount
                ELSE 0
            END
        ) AS revenue
    FROM last_paid_click AS lpc
    LEFT JOIN first_lead_after_click AS flac
        ON
            lpc.visitor_id = flac.visitor_id
            AND lpc.visit_date = flac.visit_date
            AND lpc.utm_source = flac.utm_source
            AND lpc.utm_medium = flac.utm_medium
            AND lpc.utm_campaign = flac.utm_campaign
    LEFT JOIN costs_agg AS ca
        ON
            lpc.visit_date = ca.visit_date
            AND lpc.utm_source = ca.utm_source
            AND lpc.utm_medium = ca.utm_medium
            AND lpc.utm_campaign = ca.utm_campaign
    GROUP BY
        lpc.visit_date,
        lpc.utm_source,
        lpc.utm_medium,
        lpc.utm_campaign,
        ca.total_cost
)

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

WITH last_paid_click AS (
    SELECT DISTINCT ON (s.visitor_id)
        s.visitor_id,
        s.visit_date::date AS visit_date,
        s.visit_date AS visit_datetime,
        s.source AS utm_source,
        s.medium AS utm_medium,
        s.campaign AS utm_campaign
    FROM sessions AS s
    WHERE LOWER(s.medium) != 'organic'
    ORDER BY
        s.visitor_id ASC,
        s.visit_date DESC,
        s.source ASC,
        s.medium ASC,
        s.campaign ASC
),

first_lead_after_click AS (
    SELECT DISTINCT ON (lpc.visitor_id)
        lpc.visitor_id,
        lpc.visit_date,
        lpc.utm_source,
        lpc.utm_medium,
        lpc.utm_campaign,
        l.lead_id,
        l.created_at,
        l.amount,
        l.closing_reason,
        l.status_id
    FROM last_paid_click AS lpc
    LEFT JOIN leads AS l
        ON
            lpc.visitor_id = l.visitor_id
            AND lpc.visit_datetime <= l.created_at
    ORDER BY
        lpc.visitor_id ASC,
        l.created_at ASC NULLS LAST,
        l.lead_id ASC
),

costs_agg AS (
    SELECT
        ads.campaign_date::date AS visit_date,
        ads.utm_source,
        ads.utm_medium,
        ads.utm_campaign,
        SUM(ads.daily_spent) AS total_cost
    FROM (
        SELECT
            vk.campaign_date,
            vk.utm_source,
            vk.utm_medium,
            vk.utm_campaign,
            vk.daily_spent
        FROM vk_ads AS vk

        UNION ALL

        SELECT
            ya.campaign_date,
            ya.utm_source,
            ya.utm_medium,
            ya.utm_campaign,
            ya.daily_spent
        FROM ya_ads AS ya
    ) AS ads
    GROUP BY
        ads.campaign_date::date,
        ads.utm_source,
        ads.utm_medium,
        ads.utm_campaign
),

aggregate_last_paid_click AS (
    SELECT
        lpc.visit_date,
        lpc.utm_source,
        lpc.utm_medium,
        lpc.utm_campaign,
        ca.total_cost,
        COUNT(*) AS visitors_count,
        COUNT(flac.lead_id) AS leads_count,
        COUNT(
            CASE
                WHEN
                    flac.closing_reason = 'Успешно реализовано'
                    OR flac.status_id = 142
                    THEN 1
            END
        ) AS purchases_count,
        SUM(
            CASE
                WHEN
                    flac.closing_reason = 'Успешно реализовано'
                    OR flac.status_id = 142
                    THEN flac.amount
                ELSE 0
            END
        ) AS revenue
    FROM last_paid_click AS lpc
    LEFT JOIN first_lead_after_click AS flac
        ON
            lpc.visitor_id = flac.visitor_id
            AND lpc.visit_date = flac.visit_date
            AND lpc.utm_source = flac.utm_source
            AND lpc.utm_medium = flac.utm_medium
            AND lpc.utm_campaign = flac.utm_campaign
    LEFT JOIN costs_agg AS ca
        ON
            lpc.visit_date = ca.visit_date
            AND lpc.utm_source = ca.utm_source
            AND lpc.utm_medium = ca.utm_medium
            AND lpc.utm_campaign = ca.utm_campaign
    GROUP BY
        lpc.visit_date,
        lpc.utm_source,
        lpc.utm_medium,
        lpc.utm_campaign,
        ca.total_cost
)

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
