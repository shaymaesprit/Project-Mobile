create extension if not exists btree_gist;

create or replace function public.set_updated_at()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create table if not exists public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  nom text not null default '',
  prenom text not null default '',
  email text not null,
  photo_url text,
  telephone text,
  universite text not null default '',
  niveau text not null default '',
  specialite text not null default '',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.profiles enable row level security;

create policy "Students can read their own profile"
  on public.profiles for select to authenticated
  using ((select auth.uid()) = id);

create policy "Students can create their own profile"
  on public.profiles for insert to authenticated
  with check ((select auth.uid()) = id);

create policy "Students can update their own profile"
  on public.profiles for update to authenticated
  using ((select auth.uid()) = id)
  with check ((select auth.uid()) = id);

create trigger profiles_set_updated_at
  before update on public.profiles
  for each row execute function public.set_updated_at();

create or replace function public.create_profile_for_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.profiles (id, nom, prenom, email, universite, niveau, specialite)
  values (
    new.id,
    coalesce(new.raw_user_meta_data ->> 'nom', ''),
    coalesce(new.raw_user_meta_data ->> 'prenom', ''),
    coalesce(new.email, ''),
    coalesce(new.raw_user_meta_data ->> 'universite', ''),
    coalesce(new.raw_user_meta_data ->> 'niveau', ''),
    coalesce(new.raw_user_meta_data ->> 'specialite', '')
  )
  on conflict (id) do update set email = excluded.email;
  return new;
end;
$$;

create trigger on_auth_user_created_profile
  after insert on auth.users
  for each row execute function public.create_profile_for_new_user();

create table if not exists public.courses (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  nom_cours text not null check (length(trim(nom_cours)) > 0),
  code_cours text not null default '',
  description text not null default '',
  professeur text not null default '',
  salle text not null default '',
  type_cours text not null check (type_cours in ('Cours', 'TD', 'TP')),
  jour text not null check (jour in ('Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday')),
  heure_debut time not null,
  heure_fin time not null,
  semestre text not null default '',
  couleur bigint not null default 4280303351 check (couleur between 0 and 4294967295),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (heure_debut < heure_fin),
  exclude using gist (
    user_id with =,
    (case jour
      when 'Monday' then 1
      when 'Tuesday' then 2
      when 'Wednesday' then 3
      when 'Thursday' then 4
      when 'Friday' then 5
      when 'Saturday' then 6
      else 7
    end) with =,
    (int4range(
      (extract(epoch from heure_debut) / 60)::integer,
      (extract(epoch from heure_fin) / 60)::integer,
      '[)'
    )) with &&
  )
);

create index if not exists courses_user_day_start_idx
  on public.courses (user_id, jour, heure_debut);

alter table public.courses enable row level security;

create policy "Students can read their own courses"
  on public.courses for select to authenticated
  using ((select auth.uid()) = user_id);

create policy "Students can create their own courses"
  on public.courses for insert to authenticated
  with check ((select auth.uid()) = user_id);

create policy "Students can update their own courses"
  on public.courses for update to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

create policy "Students can delete their own courses"
  on public.courses for delete to authenticated
  using ((select auth.uid()) = user_id);

create trigger courses_set_updated_at
  before update on public.courses
  for each row execute function public.set_updated_at();

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('profile-photos', 'profile-photos', false, 5242880, array['image/jpeg', 'image/png', 'image/webp'])
on conflict (id) do nothing;

create policy "Students can read their own profile photos"
  on storage.objects for select to authenticated
  using (bucket_id = 'profile-photos' and (storage.foldername(name))[1] = (select auth.uid())::text);

create policy "Students can upload their own profile photos"
  on storage.objects for insert to authenticated
  with check (bucket_id = 'profile-photos' and (storage.foldername(name))[1] = (select auth.uid())::text);

create policy "Students can update their own profile photos"
  on storage.objects for update to authenticated
  using (bucket_id = 'profile-photos' and (storage.foldername(name))[1] = (select auth.uid())::text)
  with check (bucket_id = 'profile-photos' and (storage.foldername(name))[1] = (select auth.uid())::text);

create policy "Students can delete their own profile photos"
  on storage.objects for delete to authenticated
  using (bucket_id = 'profile-photos' and (storage.foldername(name))[1] = (select auth.uid())::text);
