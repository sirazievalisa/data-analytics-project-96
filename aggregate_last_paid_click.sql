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

attributed_leads AS (
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

last_paid_click AS (
    SELECT
        ps.visitor_id,
        ps.visit_date,
        ps.utm_source,
        ps.utm_medium,
        ps.utm_campaign,
        al.lead_id,
        al.created_at,
        al.amount,
        al.closing_reason,
        al.status_id
    FROM paid_sessions AS ps
    LEFT JOIN attributed_leads AS al
        ON ps.visitor_id = al.visitor_id
        AND ps.visit_date = al.visit_date
        AND ps.utm_source = al.utm_source
        AND ps.utm_medium = al.utm_medium
        AND ps.utm_campaign = al.utm_campaign
),

lead_visitors AS (
    SELECT DISTINCT
        lpc.visitor_id
    FROM last_paid_click AS lpc
    WHERE lpc.lead_id IS NOT NULL
),

filtered_last_paid_click AS (
    SELECT
        lpc.visitor_id,
        lpc.visit_date,
        lpc.utm_source,
        lpc.utm_medium,
        lpc.utm_campaign,
        lpc.lead_id,
        lpc.created_at,
        lpc.amount,
        lpc.closing_reason,
        lpc.status_id
    FROM last_paid_click AS lpc
    WHERE lpc.lead_id IS NOT NULL

    UNION ALL

    SELECT
        lpc.visitor_id,
        lpc.visit_date,
        lpc.utm_source,
        lpc.utm_medium,
        lpc.utm_campaign,
        lpc.lead_id,
        lpc.created_at,
        lpc.amount,
        lpc.closing_reason,
        lpc.status_id
    FROM last_paid_click AS lpc
    WHERE lpc.lead_id IS NULL
      AND lpc.visitor_id NOT IN (
          SELECT lv.visitor_id
          FROM lead_visitors AS lv
      )
),

vk_costs AS (
    SELECT
        vk.campaign_date::date AS visit_date,
        vk.utm_source,
        vk.utm_medium,
        vk.utm_campaign,
        SUM(vk.daily_spent) AS total_cost
    FROM vk_ads AS vk
    GROUP BY
        vk.campaign_date::date,
        vk.utm_source,
        vk.utm_medium,
        vk.utm_campaign
),

ya_costs AS (
    SELECT
        ya.campaign_date::date AS visit_date,
        ya.utm_source,
        ya.utm_medium,
        ya.utm_campaign,
        SUM(ya.daily_spent) AS total_cost
    FROM ya_ads AS ya
    GROUP BY
        ya.campaign_date::date,
        ya.utm_source,
        ya.utm_medium,
        ya.utm_campaign
),

all_costs AS (
    SELECT
        vkc.visit_date,
        vkc.utm_source,
        vkc.utm_medium,
        vkc.utm_campaign,
        vkc.total_cost
    FROM vk_costs AS vkc

    UNION ALL

    SELECT
        yac.visit_date,
        yac.utm_source,
        yac.utm_medium,
        yac.utm_campaign,
        yac.total_cost
    FROM ya_costs AS yac
),

costs_agg AS (
    SELECT
        ac.visit_date,
        ac.utm_source,
        ac.utm_medium,
        ac.utm_campaign,
        SUM(ac.total_cost) AS total_cost
    FROM all_costs AS ac
    GROUP BY
        ac.visit_date,
        ac.utm_source,
        ac.utm_medium,
        ac.utm_campaign
)

SELECT
    flpc.visit_date::date AS visit_date,
    COUNT(flpc.visitor_id) AS visitors_count,
    flpc.utm_source,
    flpc.utm_medium,
    flpc.utm_campaign,
    ca.total_cost,
    COUNT(flpc.lead_id) AS leads_count,
    COUNT(
        CASE
            WHEN flpc.closing_reason = 'Успешно реализовано'
                OR flpc.status_id = 142
            THEN 1
        END
    ) AS purchases_count,
    SUM(
        CASE
            WHEN flpc.closing_reason = 'Успешно реализовано'
                OR flpc.status_id = 142
            THEN flpc.amount
        END
    ) AS revenue
FROM filtered_last_paid_click AS flpc
LEFT JOIN costs_agg AS ca
    ON flpc.visit_date::date = ca.visit_date
    AND flpc.utm_source = ca.utm_source
    AND flpc.utm_medium = ca.utm_medium
    AND flpc.utm_campaign = ca.utm_campaign
GROUP BY
    flpc.visit_date::date,
    flpc.utm_source,
    flpc.utm_medium,
    flpc.utm_campaign,
    ca.total_cost
ORDER BY
    revenue DESC NULLS LAST,
    flpc.visit_date::date ASC,
    visitors_count DESC,
    flpc.utm_source ASC,
    flpc.utm_medium ASC,
    flpc.utm_campaign ASC;