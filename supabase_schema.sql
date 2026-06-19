create extension if not exists pgcrypto;

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  email text unique not null,
  full_name text,
  phone text,
  role text not null check (role in ('admin', 'owner', 'worker')),
  status text default 'active',
  owner_id uuid null,
  created_at timestamptz default now()
);

create table if not exists public.forest_owners (
  id uuid primary key default gen_random_uuid(),
  owner_code text unique,
  owner_name text not null,
  type text check (type in ('individual', 'company', 'cooperative')),
  identity_no text,
  address text,
  province text,
  total_area_ha numeric default 0,
  phone text,
  email text,
  created_at timestamptz default now()
);


do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'profiles_owner_id_fkey'
      and conrelid = 'public.profiles'::regclass
  ) then
    alter table public.profiles
      add constraint profiles_owner_id_fkey
      foreign key (owner_id) references public.forest_owners(id);
  end if;
end $$;

create table if not exists public.forest_projects (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid references public.forest_owners(id),
  project_code text unique,
  project_name text not null,
  province text,
  district text,
  commune text,
  forest_type text,
  tree_species text,
  year_planted int,
  status text default 'pending' check (status in ('pending', 'approved', 'rejected', 'draft', 'active', 'suspended')),
  area_ha numeric default 0,
  created_at timestamptz default now()
);

create table if not exists public.checkins (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users(id),
  project_id uuid null references public.forest_projects(id),
  latitude double precision,
  longitude double precision,
  checked_at timestamptz default now(),
  created_at timestamptz default now()
);

create table if not exists public.logbooks (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users(id),
  owner_id uuid null references public.forest_owners(id),
  project_id uuid null references public.forest_projects(id),
  work_type text,
  description text,
  latitude double precision,
  longitude double precision,
  photo_urls text[] default '{}',
  is_synced boolean default true,
  created_at timestamptz default now()
);

create table if not exists public.inventory_plots (
  id uuid primary key default gen_random_uuid(),
  project_id uuid references public.forest_projects(id),
  plot_code text,
  latitude double precision,
  longitude double precision,
  area numeric,
  created_at timestamptz default now()
);

create table if not exists public.inventory_trees (
  id uuid primary key default gen_random_uuid(),
  plot_id uuid references public.inventory_plots(id),
  species text,
  dbh numeric,
  height numeric,
  quantity int,
  created_at timestamptz default now()
);

create table if not exists public.carbon_factors (
  id uuid primary key default gen_random_uuid(),
  species text unique,
  factor numeric,
  created_at timestamptz default now()
);

create table if not exists public.notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid null references auth.users(id),
  title text,
  message text,
  type text,
  is_read boolean default false,
  created_at timestamptz default now()
);

create table if not exists public.files (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid null references public.forest_owners(id),
  project_id uuid null references public.forest_projects(id),
  file_group text,
  file_name text,
  file_url text,
  created_at timestamptz default now()
);

create or replace function public.current_user_role()
returns text
language sql
stable
security definer
set search_path = public
as $$
  select role from public.profiles where id = auth.uid()
$$;

create or replace function public.validate_project_owner_area_and_province()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  owner_prov text;
  user_role text;
begin
  -- Get owner registered province
  select province into owner_prov
  from public.forest_owners
  where id = new.owner_id;

  -- Get the current authenticated user's role from profiles
  select role into user_role
  from public.profiles
  where id = auth.uid();

  -- If the user is admin, they can bypass area and province checks and projects are auto-approved
  if user_role = 'admin' then
    new.status := 'approved';
    return new;
  end if;

  -- Enforce province restriction for owners (if province is defined for owner)
  if owner_prov is not null and new.province is not null and lower(new.province) != lower(owner_prov) then
    raise exception 'Owner is only allowed to create projects in their registered province (%)', owner_prov;
  end if;

  return new;
end;
$$;

drop trigger if exists trigger_validate_project on public.forest_projects;
create trigger trigger_validate_project
before insert or update on public.forest_projects
for each row
execute function public.validate_project_owner_area_and_province();

alter table public.profiles enable row level security;
alter table public.forest_owners enable row level security;
alter table public.forest_projects enable row level security;
alter table public.checkins enable row level security;
alter table public.logbooks enable row level security;
alter table public.inventory_plots enable row level security;
alter table public.inventory_trees enable row level security;
alter table public.carbon_factors enable row level security;
alter table public.notifications enable row level security;
alter table public.files enable row level security;

drop policy if exists "authenticated read profiles" on public.profiles;
create policy "authenticated read profiles"
on public.profiles for select
to authenticated
using (true);

drop policy if exists "users update own profile" on public.profiles;
create policy "users update own profile"
on public.profiles for update
to authenticated
using (id = auth.uid())
with check (id = auth.uid());

drop policy if exists "admin full profiles" on public.profiles;
create policy "admin full profiles"
on public.profiles for all
to authenticated
using (public.current_user_role() = 'admin')
with check (public.current_user_role() = 'admin');

drop policy if exists "authenticated read owners" on public.forest_owners;
create policy "authenticated read owners"
on public.forest_owners for select
to authenticated
using (true);

drop policy if exists "admin full owners" on public.forest_owners;
create policy "admin full owners"
on public.forest_owners for all
to authenticated
using (public.current_user_role() = 'admin')
with check (public.current_user_role() = 'admin');

drop policy if exists "authenticated read projects" on public.forest_projects;
create policy "authenticated read projects"
on public.forest_projects for select
to authenticated
using (true);

drop policy if exists "admin full projects" on public.forest_projects;
create policy "admin full projects"
on public.forest_projects for all
to authenticated
using (public.current_user_role() = 'admin')
with check (public.current_user_role() = 'admin');

drop policy if exists "owners insert own pending projects" on public.forest_projects;
create policy "owners insert own pending projects"
on public.forest_projects for insert
to authenticated
with check (
  public.current_user_role() = 'owner'
  and owner_id = (select owner_id from public.profiles where id = auth.uid())
  and status = 'pending'
);

drop policy if exists "authenticated read logbooks" on public.logbooks;
create policy "authenticated read logbooks"
on public.logbooks for select
to authenticated
using (true);

drop policy if exists "workers insert own logbooks" on public.logbooks;
create policy "workers insert own logbooks"
on public.logbooks for insert
to authenticated
with check (user_id = auth.uid());

drop policy if exists "workers update own logbooks" on public.logbooks;
create policy "workers update own logbooks"
on public.logbooks for update
to authenticated
using (user_id = auth.uid())
with check (user_id = auth.uid());

drop policy if exists "admin full logbooks" on public.logbooks;
create policy "admin full logbooks"
on public.logbooks for all
to authenticated
using (public.current_user_role() = 'admin')
with check (public.current_user_role() = 'admin');

drop policy if exists "authenticated read checkins" on public.checkins;
create policy "authenticated read checkins"
on public.checkins for select
to authenticated
using (true);

drop policy if exists "workers insert own checkins" on public.checkins;
create policy "workers insert own checkins"
on public.checkins for insert
to authenticated
with check (user_id = auth.uid());

drop policy if exists "workers update own checkins" on public.checkins;
create policy "workers update own checkins"
on public.checkins for update
to authenticated
using (user_id = auth.uid())
with check (user_id = auth.uid());

drop policy if exists "admin full checkins" on public.checkins;
create policy "admin full checkins"
on public.checkins for all
to authenticated
using (public.current_user_role() = 'admin')
with check (public.current_user_role() = 'admin');

drop policy if exists "authenticated read inventory plots" on public.inventory_plots;
create policy "authenticated read inventory plots"
on public.inventory_plots for select
to authenticated
using (true);

drop policy if exists "admin full inventory plots" on public.inventory_plots;
create policy "admin full inventory plots"
on public.inventory_plots for all
to authenticated
using (public.current_user_role() = 'admin')
with check (public.current_user_role() = 'admin');

drop policy if exists "owners insert plots for approved projects" on public.inventory_plots;
create policy "owners insert plots for approved projects"
on public.inventory_plots for insert
to authenticated
with check (
  (
    public.current_user_role() in ('owner', 'worker')
    and (select owner_id from public.profiles where id = auth.uid()) = (select owner_id from public.forest_projects where id = project_id)
    and (select status from public.forest_projects where id = project_id) = 'approved'
  )
  or public.current_user_role() = 'admin'
);

drop policy if exists "authenticated read inventory trees" on public.inventory_trees;
create policy "authenticated read inventory trees"
on public.inventory_trees for select
to authenticated
using (true);

drop policy if exists "admin full inventory trees" on public.inventory_trees;
create policy "admin full inventory trees"
on public.inventory_trees for all
to authenticated
using (public.current_user_role() = 'admin')
with check (public.current_user_role() = 'admin');

drop policy if exists "owners insert trees for approved projects" on public.inventory_trees;
create policy "owners insert trees for approved projects"
on public.inventory_trees for insert
to authenticated
with check (
  (
    public.current_user_role() in ('owner', 'worker')
    and (select owner_id from public.profiles where id = auth.uid()) = (
      select p.owner_id from public.forest_projects p
      join public.inventory_plots pl on pl.project_id = p.id
      where pl.id = plot_id
    )
    and (
      select p.status from public.forest_projects p
      join public.inventory_plots pl on pl.project_id = p.id
      where pl.id = plot_id
    ) = 'approved'
  )
  or public.current_user_role() = 'admin'
);

drop policy if exists "authenticated read carbon factors" on public.carbon_factors;
create policy "authenticated read carbon factors"
on public.carbon_factors for select
to authenticated
using (true);

drop policy if exists "admin full carbon factors" on public.carbon_factors;
create policy "admin full carbon factors"
on public.carbon_factors for all
to authenticated
using (public.current_user_role() = 'admin')
with check (public.current_user_role() = 'admin');

drop policy if exists "users read own notifications" on public.notifications;
create policy "users read own notifications"
on public.notifications for select
to authenticated
using (user_id is null or user_id = auth.uid());

drop policy if exists "admin full notifications" on public.notifications;
create policy "admin full notifications"
on public.notifications for all
to authenticated
using (public.current_user_role() = 'admin')
with check (public.current_user_role() = 'admin');

drop policy if exists "authenticated read files" on public.files;
create policy "authenticated read files"
on public.files for select
to authenticated
using (true);

drop policy if exists "admin full files" on public.files;
create policy "admin full files"
on public.files for all
to authenticated
using (public.current_user_role() = 'admin')
with check (public.current_user_role() = 'admin');

insert into storage.buckets (id, name, public)
values ('logbook-images', 'logbook-images', true)
on conflict (id) do update set public = excluded.public;

drop policy if exists "Public read logbook images" on storage.objects;
create policy "Public read logbook images"
on storage.objects
for select
using (bucket_id = 'logbook-images');

drop policy if exists "Authenticated upload logbook images" on storage.objects;
create policy "Authenticated upload logbook images"
on storage.objects
for insert
to authenticated
with check (bucket_id = 'logbook-images');

drop policy if exists "Authenticated update own logbook images" on storage.objects;
create policy "Authenticated update own logbook images"
on storage.objects
for update
to authenticated
using (bucket_id = 'logbook-images');
