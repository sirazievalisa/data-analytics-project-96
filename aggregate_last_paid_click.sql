WITH paid_sessions AS (
    SELECT
        s.visitor_id,
        s.visit_date,
        s.source AS utm_source,
        s.medium AS utm_medium,
        s.campaign AS utm_campaign
    FROM sessions AS s
    WHERE LOWER(s.medium) IN (
        'cpc',
        'cpm',
        'cpa',
        'youtube',
        'cpp',
        'tg',
        'social'
    )
),

ranked_attribution AS (
    SELECT
        ps.visitor_id,
        ps.visit_date,
        ps.utm_source,
        ps.utm_medium,
        ps.utm_campaign,
        l.lead_id,
        l.created_at,
        l.amount,
        l.closing_reason,
        l.status_id,
        ROW_NUMBER() OVER (
            PARTITION BY l.lead_id
            ORDER BY ps.visit_date DESC
        ) AS rn
    FROM paid_sessions AS ps
    LEFT JOIN leads AS l
        ON ps.visitor_id = l.visitor_id
        AND ps.visit_date <= l.created_at
),

attributed AS (
    SELECT
        ra.visitor_id,
        ra.visit_date,
        ra.utm_source,
        ra.utm_medium,
        ra.utm_campaign,
        ra.lead_id,
        ra.created_at,
        ra.amount,
        ra.closing_reason,
        ra.status_id
    FROM ranked_attribution AS ra
    WHERE ra.lead_id IS NOT NULL
      AND ra.rn = 1
),

vk_costs AS (
    SELECT
        campaign_date::date AS visit_date,
        utm_source,
        utm_medium,
        utm_campaign,
        SUM(daily_spent) AS total_cost
    FROM vk_ads
    GROUP BY 1, 2, 3, 4
),

ya_costs AS (
    SELECT
        campaign_date::date AS visit_date,
        utm_source,
        utm_medium,
        utm_campaign,
        SUM(daily_spent) AS total_cost
    FROM ya_ads
    GROUP BY 1, 2, 3, 4
),

all_costs AS (
    SELECT * FROM vk_costs
    UNION ALL
    SELECT * FROM ya_costs
),

costs_agg AS (
    SELECT
        visit_date,
        utm_source,
        utm_medium,
        utm_campaign,
        SUM(total_cost) AS total_cost
    FROM all_costs
    GROUP BY 1, 2, 3, 4
)

SELECT
    ps.visit_date::date AS visit_date,
    COUNT(DISTINCT ps.visitor_id) AS visitors_count,
    ps.utm_source,
    ps.utm_medium,
    ps.utm_campaign,
    c.total_cost,
    COUNT(DISTINCT a.lead_id) AS leads_count,
    COUNT(
        DISTINCT CASE
            WHEN a.closing_reason = 'Успешно реализовано'
                OR a.status_id = 142
            THEN a.lead_id
        END
    ) AS purchases_count,
    SUM(
        CASE
            WHEN a.closing_reason = 'Успешно реализовано'
                OR a.status_id = 142
            THEN a.amount
            ELSE NULL
        END
    ) AS revenue
FROM paid_sessions AS ps
LEFT JOIN attributed AS a
    ON ps.visitor_id = a.visitor_id
    AND ps.visit_date = a.visit_date
    AND ps.utm_source = a.utm_source
    AND ps.utm_medium = a.utm_medium
    AND ps.utm_campaign = a.utm_campaign
LEFT JOIN costs_agg AS c
    ON ps.visit_date::date = c.visit_date
    AND ps.utm_source = c.utm_source
    AND ps.utm_medium = c.utm_medium
    AND ps.utm_campaign = c.utm_campaign
GROUP BY
    ps.visit_date::date,
    ps.utm_source,
    ps.utm_medium,
    ps.utm_campaign,
    c.total_cost
ORDER BY
    revenue DESC NULLS LAST,
    ps.visit_date::date ASC,
    visitors_count DESC,
    ps.utm_source ASC,
    ps.utm_medium ASC,
    ps.utm_campaign ASC;