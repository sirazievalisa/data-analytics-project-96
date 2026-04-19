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
        l.lead_id::text AS lead_id,
        l.created_at::timestamp AS created_at,
        l.amount::numeric AS amount,
        l.closing_reason::text AS closing_reason,
        l.status_id::text AS status_id,
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

sessions_without_leads AS (
    SELECT
        ps.visitor_id,
        ps.visit_date,
        ps.utm_source,
        ps.utm_medium,
        ps.utm_campaign,
        NULL::text AS lead_id,
        NULL::timestamp AS created_at,
        NULL::numeric AS amount,
        NULL::text AS closing_reason,
        NULL::text AS status_id
    FROM paid_sessions AS ps
    WHERE NOT EXISTS (
        SELECT 1
        FROM leads AS l
        WHERE l.visitor_id = ps.visitor_id
    )
),

last_paid_click_result AS (
    SELECT
        a.visitor_id,
        a.visit_date,
        a.utm_source,
        a.utm_medium,
        a.utm_campaign,
        a.lead_id,
        a.created_at,
        a.amount,
        a.closing_reason,
        a.status_id
    FROM attributed AS a

    UNION ALL

    SELECT
        swl.visitor_id,
        swl.visit_date,
        swl.utm_source,
        swl.utm_medium,
        swl.utm_campaign,
        swl.lead_id,
        swl.created_at,
        swl.amount,
        swl.closing_reason,
        swl.status_id
    FROM sessions_without_leads AS swl
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
    lpcr.visit_date::date AS visit_date,
    lpcr.utm_source,
    lpcr.utm_medium,
    lpcr.utm_campaign,
    COUNT(lpcr.visitor_id) AS visitors_count,
    COUNT(lpcr.lead_id) AS leads_count,
    COUNT(
        CASE
            WHEN lpcr.closing_reason = 'Успешно реализовано'
                OR lpcr.status_id = '142'
            THEN 1
        END
    ) AS purchases_count,
    SUM(
        CASE
            WHEN lpcr.closing_reason = 'Успешно реализовано'
                OR lpcr.status_id = '142'
            THEN lpcr.amount
        END
    ) AS revenue,
    ca.total_cost
FROM last_paid_click_result AS lpcr
LEFT JOIN costs_agg AS ca
    ON lpcr.visit_date::date = ca.visit_date
    AND lpcr.utm_source = ca.utm_source
    AND lpcr.utm_medium = ca.utm_medium
    AND lpcr.utm_campaign = ca.utm_campaign
GROUP BY
    lpcr.visit_date::date,
    lpcr.utm_source,
    lpcr.utm_medium,
    lpcr.utm_campaign,
    ca.total_cost
ORDER BY
    revenue DESC NULLS LAST,
    lpcr.visit_date::date ASC,
    visitors_count DESC,
    lpcr.utm_source ASC,
    lpcr.utm_medium ASC,
    lpcr.utm_campaign ASC;