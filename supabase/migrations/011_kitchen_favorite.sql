-- Rezept-Favoriten (Herz) pro Haushalt; bisherige 4–5-Sterne-Rezepte übernommen
alter table public.kitchen_meta add column if not exists favorite boolean not null default false;
update public.kitchen_meta set favorite = true where rating >= 4;
