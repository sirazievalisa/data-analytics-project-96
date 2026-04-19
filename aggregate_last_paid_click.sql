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

aggregated_data AS (
    SELECT
        lpc.visit_date,
        lpc.utm_source,
        lpc.utm_medium,
        lpc.utm_campaign,
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
    GROUP BY
        lpc.visit_date,
        lpc.utm_source,
        lpc.utm_medium,
        lpc.utm_campaign
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
)

SELECT
    ad.visit_date,
    ad.utm_source,
    ad.utm_medium,
    ad.utm_campaign,
    ad.visitors_count,
    ad.leads_count,
    ad.purchases_count,
    ad.revenue,
    ca.total_cost
FROM aggregated_data AS ad
LEFT JOIN costs_agg AS ca
    ON
        ad.visit_date = ca.visit_date
        AND ad.utm_source = ca.utm_source
        AND ad.utm_medium = ca.utm_medium
        AND ad.utm_campaign = ca.utm_campaign
ORDER BY
    ad.revenue DESC NULLS LAST,
    ad.visit_date ASC,
    ad.visitors_count DESC,
    ad.utm_source ASC,
    ad.utm_medium ASC,
    ad.utm_campaign ASC;
