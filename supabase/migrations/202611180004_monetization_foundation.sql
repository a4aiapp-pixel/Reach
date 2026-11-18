-- Monetization-ready data model. All payment features are OFF until verified.
-- Never treat client metadata as proof of a paid subscription or verified business.

CREATE TABLE public.reach_entitlements (
 user_id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
 tier text NOT NULL DEFAULT 'free'
    CHECK(tier IN ('free','plus','business_pro','organization')),
 status text NOT NULL DEFAULT 'inactive'
    CHECK(status IN ('inactive','trialing','active','past_due','cancelled')),
 provider text NOT NULL DEFAULT 'none'
    CHECK(provider IN ('none','google_play','external_eligible')),
 provider_subscription_ref text,
 valid_until timestamptz,
 updated_at timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE public.reach_entitlements ENABLE ROW LEVEL SECURITY;
CREATE POLICY entitlements_owner_read ON public.reach_entitlements
 FOR SELECT TO authenticated USING(user_id=auth.uid());
REVOKE ALL ON public.reach_entitlements FROM PUBLIC,anon,authenticated;
GRANT SELECT ON public.reach_entitlements TO authenticated;

CREATE TABLE public.reach_business_profiles (
 owner_id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
 business_name text NOT NULL CHECK(length(btrim(business_name)) BETWEEN 3 AND 100),
 description text NOT NULL DEFAULT '' CHECK(length(description)<=650),
 city text NOT NULL DEFAULT '' CHECK(length(city)<=100),
 country text NOT NULL DEFAULT '' CHECK(length(country)<=100),
 website text CHECK(website IS NULL OR (length(website)<=250 AND website ~ '^https://')),
 verified boolean NOT NULL DEFAULT false,
 review_status text NOT NULL DEFAULT 'draft'
    CHECK(review_status IN ('draft','submitted','published','rejected','suspended')),
 created_at timestamptz NOT NULL DEFAULT now(),
 updated_at timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE public.reach_business_profiles ENABLE ROW LEVEL SECURITY;
CREATE POLICY business_profile_read ON public.reach_business_profiles
 FOR SELECT TO authenticated
 USING(owner_id=auth.uid() OR (verified AND review_status='published'));
CREATE POLICY business_profile_create ON public.reach_business_profiles
 FOR INSERT TO authenticated
 WITH CHECK(owner_id=auth.uid() AND NOT verified
  AND review_status IN ('draft','submitted')
  AND EXISTS(SELECT 1 FROM public.profiles p WHERE p.id=auth.uid() AND NOT p.suspended));
CREATE POLICY business_profile_edit ON public.reach_business_profiles
 FOR UPDATE TO authenticated
 USING(owner_id=auth.uid() AND review_status IN ('draft','submitted','rejected'))
 WITH CHECK(owner_id=auth.uid() AND review_status IN ('draft','submitted','rejected'));
REVOKE ALL ON public.reach_business_profiles FROM PUBLIC,anon,authenticated;
GRANT SELECT,INSERT ON public.reach_business_profiles TO authenticated;
GRANT UPDATE(business_name,description,city,country,website,review_status)
 ON public.reach_business_profiles TO authenticated;

-- Sponsored placements can only be authorized and funded through privileged,
-- audited backend workflows. A user may not buy priority by editing a profile.
CREATE TABLE public.reach_sponsored_campaigns (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 business_owner_id uuid NOT NULL REFERENCES public.reach_business_profiles(owner_id) ON DELETE CASCADE,
 headline text NOT NULL CHECK(length(headline) BETWEEN 8 AND 110),
 description text NOT NULL DEFAULT '' CHECK(length(description)<=500),
 target_city text NOT NULL DEFAULT '',
 target_country text NOT NULL DEFAULT '',
 campaign_status text NOT NULL DEFAULT 'draft'
   CHECK(campaign_status IN ('draft','active','paused','ended')),
 starts_at timestamptz,
 ends_at timestamptz,
 created_at timestamptz NOT NULL DEFAULT now(),
 CHECK(ends_at IS NULL OR starts_at IS NULL OR ends_at>starts_at)
);
CREATE INDEX reach_sponsors_active ON public.reach_sponsored_campaigns(
 campaign_status,starts_at,ends_at);
ALTER TABLE public.reach_sponsored_campaigns ENABLE ROW LEVEL SECURITY;
CREATE POLICY sponsored_active_read ON public.reach_sponsored_campaigns
 FOR SELECT TO authenticated
 USING(campaign_status='active'
    AND starts_at <=now() AND ends_at>now()
    AND EXISTS(SELECT 1 FROM public.reach_business_profiles b
      WHERE b.owner_id=business_owner_id AND b.verified
        AND b.review_status='published'));
REVOKE ALL ON public.reach_sponsored_campaigns FROM PUBLIC,anon,authenticated;
GRANT SELECT ON public.reach_sponsored_campaigns TO authenticated;

-- The financial ledger is private (not in the REST-exposed public schema).
-- Record only reconciled provider/settlement data; never fake impressions
-- or grant tiers based on client-reported transactions.
CREATE TABLE reach_private.revenue_events(
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 source text NOT NULL CHECK(source IN ('google_play','admob','sponsorship','other')),
 source_event_id text NOT NULL UNIQUE,
 currency text NOT NULL CHECK(currency ~ '^[A-Z]{3}$'),
 gross_minor bigint NOT NULL DEFAULT 0 CHECK(gross_minor>=0),
 provider_fee_minor bigint NOT NULL DEFAULT 0 CHECK(provider_fee_minor>=0),
 booked_at timestamptz NOT NULL,
 created_at timestamptz NOT NULL DEFAULT now(),
 details jsonb NOT NULL DEFAULT '{}'::jsonb
);
ALTER TABLE reach_private.revenue_events ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON reach_private.revenue_events FROM PUBLIC,anon,authenticated;

COMMENT ON TABLE public.reach_entitlements IS
 'Backend-only active paid tiers. No client can write or activate a subscription.';
COMMENT ON TABLE public.reach_sponsored_campaigns IS
 'Sponsored cards must always show a Sponsored label and are invisible until approved.';
