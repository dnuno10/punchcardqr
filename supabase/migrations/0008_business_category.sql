-- PunchCardQR · 0008 · Business category
-- Lets owners tag their business with an industry during onboarding so we can
-- offer tailored card templates (colors, punch icon, default copy) and, later,
-- segment analytics/benchmarks by vertical. Purely additive — no RLS changes
-- needed, existing policies on `businesses` already cover this column.

create type business_category as enum (
  'coffee_shop',
  'restaurant',
  'bakery',
  'bar_nightlife',
  'salon_spa',
  'gym_fitness',
  'retail_store',
  'car_wash',
  'pet_services',
  'professional_services',
  'healthcare',
  'other'
);

alter table businesses
  add column category business_category not null default 'other';
