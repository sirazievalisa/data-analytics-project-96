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

ranked_lead_sessions AS (
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
            PARTITION BY ps.visitor_id
            ORDER BY ps.visit_date DESC
        ) AS rn
    FROM paid_sessions AS ps
    INNER JOIN leads AS l
        ON ps.visitor_id = l.visitor_id
        AND ps.visit_date <= l.created_at
),

attributed AS (
    SELECT
        rls.visitor_id,
        rls.visit_date,
        rls.utm_source,
        rls.utm_medium,
        rls.utm_campaign,
        rls.lead_id,
        rls.created_at,
        rls.amount,
        rls.closing_reason,
        rls.status_id
    FROM ranked_lead_sessions AS rls
    WHERE rls.rn = 1
),

ranked_no_lead_sessions AS (
    SELECT
        ps.visitor_id,
        ps.visit_date,
        ps.utm_source,
        ps.utm_medium,
        ps.utm_campaign,
        ROW_NUMBER() OVER (
            PARTITION BY ps.visitor_id
            ORDER BY ps.visit_date DESC
        ) AS rn
    FROM paid_sessions AS ps
    LEFT JOIN leads AS l
        ON ps.visitor_id = l.visitor_id
    WHERE l.visitor_id IS NULL
),

no_lead_last_click AS (
    SELECT
        rnls.visitor_id,
        rnls.visit_date,
        rnls.utm_source,
        rnls.utm_medium,
        rnls.utm_campaign,
        NULL::text AS lead_id,
        NULL::timestamp AS created_at,
        NULL::numeric AS amount,
        NULL::text AS closing_reason,
        NULL::integer AS status_id
    FROM ranked_no_lead_sessions AS rnls
    WHERE rnls.rn = 1
),

last_paid_click AS (
    SELECT
        a.visitor_id,
        a.visit_date,
        a.utm_source,
        a.utm_medium,
        a.utm_campaign,
        a.lead_id::text AS lead_id,
        a.created_at,
        a.amount,
        a.closing_reason,
        a.status_id
    FROM attributed AS a

    UNION ALL

    SELECT
        nlc.visitor_id,
        nlc.visit_date,
        nlc.utm_source,
        nlc.utm_medium,
        nlc.utm_campaign,
        nlc.lead_id,
        nlc.created_at,
        nlc.amount,
        nlc.closing_reason,
        nlc.status_id
    FROM no_lead_last_click AS nlc
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
    lpc.visit_date::date AS visit_date,
    COUNT(lpc.visitor_id) AS visitors_count,
    lpc.utm_source,
    lpc.utm_medium,
    lpc.utm_campaign,
    ca.total_cost,
    COUNT(lpc.lead_id) AS leads_count,
    COUNT(
        CASE
            WHEN lpc.closing_reason = 'Успешно реализовано'
                OR lpc.status_id = 142
            THEN 1
        END
    ) AS purchases_count,
    SUM(
        CASE
            WHEN lpc.closing_reason = 'Успешно реализовано'
                OR lpc.status_id = 142
            THEN lpc.amount
        END
    ) AS revenue
FROM last_paid_click AS lpc
LEFT JOIN costs_agg AS ca
    ON lpc.visit_date::date = ca.visit_date
    AND lpc.utm_source = ca.utm_source
    AND lpc.utm_medium = ca.utm_medium
    AND lpc.utm_campaign = ca.utm_campaign
GROUP BY
    lpc.visit_date::date,
    lpc.utm_source,
    lpc.utm_medium,
    lpc.utm_campaign,
    ca.total_cost
ORDER BY
    revenue DESC NULLS LAST,
    lpc.visit_date::date ASC,
    visitors_count DESC,
    lpc.utm_source ASC,
    lpc.utm_medium ASC,
    lpc.utm_campaign ASC;