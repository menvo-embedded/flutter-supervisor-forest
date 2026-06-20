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
  status text default 'draft',
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

alter table public.checkins
  add column if not exists type text default 'check_in',
  add column if not exists note text default '';

alter table public.inventory_plots
  add column if not exists elevation numeric default 0;

alter table public.forest_projects
  add column if not exists boundary_geojson jsonb,
  add column if not exists centroid_lat double precision,
  add column if not exists centroid_lng double precision,
  add column if not exists perimeter_km numeric default 0;

create table if not exists public.carbon_calculations (
  id uuid primary key default gen_random_uuid(),
  project_id uuid not null references public.forest_projects(id) on delete cascade,
  created_by uuid null references auth.users(id) on delete set null,
  method text not null default 'IPCC mặc định',
  biomass_kg numeric not null default 0,
  carbon_stock numeric not null default 0,
  co2e numeric not null default 0,
  status text not null default 'draft' check (status in ('draft', 'approved')),
  created_at timestamptz default now()
);

do $$
begin
  if exists (
    select 1 from pg_constraint
    where conname = 'carbon_calculations_created_by_fkey'
      and conrelid = 'public.carbon_calculations'::regclass
  ) then
    alter table public.carbon_calculations drop constraint carbon_calculations_created_by_fkey;
  end if;
  alter table public.carbon_calculations
    add constraint carbon_calculations_created_by_fkey
    foreign key (created_by) references auth.users(id) on delete set null;
exception when duplicate_object then null;
end $$;

create or replace function public.current_user_role()
returns text
language sql
stable
security definer
set search_path = public
as $$
  select role from public.profiles where id = auth.uid()
$$;

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
alter table public.carbon_calculations enable row level security;

create or replace function public.current_user_owner_id()
returns uuid
language sql
stable
security definer
set search_path = public
as $$
  select owner_id from public.profiles where id = auth.uid()
$$;

drop policy if exists "authenticated read profiles" on public.profiles;
create policy "authenticated read profiles"
on public.profiles for select
to authenticated
using (true);

drop policy if exists "users update own profile" on public.profiles;

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

drop policy if exists "users update own notifications" on public.notifications;
create policy "users update own notifications"
on public.notifications for update
to authenticated
using (user_id = auth.uid())
with check (user_id = auth.uid());

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

insert into storage.buckets (id, name, public)
values ('project-files', 'project-files', false)
on conflict (id) do update set public = excluded.public;

drop policy if exists "Public read logbook images" on storage.objects;
create policy "Public read logbook images"
on storage.objects
for select
using (bucket_id = 'logbook-images');

drop policy if exists "Authenticated read project files" on storage.objects;
create policy "Authenticated read project files"
on storage.objects for select
to authenticated
using (
  bucket_id = 'project-files'
  and (
    public.current_user_role() = 'admin'
    or (storage.foldername(name))[1] = public.current_user_owner_id()::text
  )
);

drop policy if exists "Authenticated upload project files" on storage.objects;
create policy "Authenticated upload project files"
on storage.objects for insert
to authenticated
with check (
  bucket_id = 'project-files'
  and (
    public.current_user_role() = 'admin'
    or (
      public.current_user_role() = 'owner'
      and (storage.foldername(name))[1] = public.current_user_owner_id()::text
    )
  )
);

drop policy if exists "Authenticated update project files" on storage.objects;
create policy "Authenticated update project files"
on storage.objects for update
to authenticated
using (
  bucket_id = 'project-files'
  and (
    public.current_user_role() = 'admin'
    or (storage.foldername(name))[1] = public.current_user_owner_id()::text
  )
)
with check (
  bucket_id = 'project-files'
  and (
    public.current_user_role() = 'admin'
    or (storage.foldername(name))[1] = public.current_user_owner_id()::text
  )
);

drop policy if exists "Authenticated delete project files" on storage.objects;
create policy "Authenticated delete project files"
on storage.objects for delete
to authenticated
using (
  bucket_id = 'project-files'
  and (
    public.current_user_role() = 'admin'
    or (storage.foldername(name))[1] = public.current_user_owner_id()::text
  )
);

-- Production owner/worker scopes. These override the broad read policies above.
drop policy if exists "authenticated read profiles" on public.profiles;
drop policy if exists "scoped read profiles" on public.profiles;
create policy "scoped read profiles"
on public.profiles for select
to authenticated
using (
  id = auth.uid()
  or public.current_user_role() = 'admin'
  or (
    public.current_user_role() = 'owner'
    and owner_id = public.current_user_owner_id()
  )
);

drop policy if exists "authenticated read owners" on public.forest_owners;
drop policy if exists "scoped read owners" on public.forest_owners;
create policy "scoped read owners"
on public.forest_owners for select
to authenticated
using (
  public.current_user_role() = 'admin'
  or id = public.current_user_owner_id()
);

drop policy if exists "authenticated read projects" on public.forest_projects;
drop policy if exists "scoped read projects" on public.forest_projects;
create policy "scoped read projects"
on public.forest_projects for select
to authenticated
using (
  public.current_user_role() = 'admin'
  or owner_id = public.current_user_owner_id()
);

drop policy if exists "owner manage own projects" on public.forest_projects;
create policy "owner manage own projects"
on public.forest_projects for all
to authenticated
using (
  public.current_user_role() = 'owner'
  and owner_id = public.current_user_owner_id()
)
with check (
  public.current_user_role() = 'owner'
  and owner_id = public.current_user_owner_id()
);

drop policy if exists "authenticated read logbooks" on public.logbooks;
drop policy if exists "scoped read logbooks" on public.logbooks;
create policy "scoped read logbooks"
on public.logbooks for select
to authenticated
using (
  public.current_user_role() = 'admin'
  or user_id = auth.uid()
  or (
    public.current_user_role() = 'owner'
    and exists (
      select 1 from public.forest_projects project
      where project.id = logbooks.project_id
        and project.owner_id = public.current_user_owner_id()
    )
  )
);

drop policy if exists "authenticated read checkins" on public.checkins;
drop policy if exists "scoped read checkins" on public.checkins;
create policy "scoped read checkins"
on public.checkins for select
to authenticated
using (
  public.current_user_role() = 'admin'
  or user_id = auth.uid()
  or (
    public.current_user_role() = 'owner'
    and exists (
      select 1 from public.profiles worker
      where worker.id = checkins.user_id
        and worker.owner_id = public.current_user_owner_id()
    )
  )
);

drop policy if exists "authenticated read inventory plots" on public.inventory_plots;
drop policy if exists "scoped read inventory plots" on public.inventory_plots;
create policy "scoped read inventory plots"
on public.inventory_plots for select
to authenticated
using (
  public.current_user_role() = 'admin'
  or exists (
    select 1 from public.forest_projects project
    where project.id = inventory_plots.project_id
      and project.owner_id = public.current_user_owner_id()
  )
);

drop policy if exists "owner manage own inventory plots" on public.inventory_plots;
create policy "owner manage own inventory plots"
on public.inventory_plots for all
to authenticated
using (
  public.current_user_role() in ('owner', 'worker')
  and exists (
    select 1 from public.forest_projects project
    where project.id = inventory_plots.project_id
      and project.owner_id = public.current_user_owner_id()
  )
)
with check (
  public.current_user_role() in ('owner', 'worker')
  and exists (
    select 1 from public.forest_projects project
    where project.id = inventory_plots.project_id
      and project.owner_id = public.current_user_owner_id()
  )
);

drop policy if exists "authenticated read inventory trees" on public.inventory_trees;
drop policy if exists "scoped read inventory trees" on public.inventory_trees;
create policy "scoped read inventory trees"
on public.inventory_trees for select
to authenticated
using (
  public.current_user_role() = 'admin'
  or exists (
    select 1
    from public.inventory_plots plot
    join public.forest_projects project on project.id = plot.project_id
    where plot.id = inventory_trees.plot_id
      and project.owner_id = public.current_user_owner_id()
  )
);

drop policy if exists "owner manage own inventory trees" on public.inventory_trees;
create policy "owner manage own inventory trees"
on public.inventory_trees for all
to authenticated
using (
  public.current_user_role() in ('owner', 'worker')
  and exists (
    select 1
    from public.inventory_plots plot
    join public.forest_projects project on project.id = plot.project_id
    where plot.id = inventory_trees.plot_id
      and project.owner_id = public.current_user_owner_id()
  )
)
with check (
  public.current_user_role() in ('owner', 'worker')
  and exists (
    select 1
    from public.inventory_plots plot
    join public.forest_projects project on project.id = plot.project_id
    where plot.id = inventory_trees.plot_id
      and project.owner_id = public.current_user_owner_id()
  )
);

drop policy if exists "scoped read carbon calculations" on public.carbon_calculations;
create policy "scoped read carbon calculations"
on public.carbon_calculations for select
to authenticated
using (
  public.current_user_role() = 'admin'
  or exists (
    select 1 from public.forest_projects project
    where project.id = carbon_calculations.project_id
      and project.owner_id = public.current_user_owner_id()
  )
);

drop policy if exists "admin full carbon calculations" on public.carbon_calculations;
create policy "admin full carbon calculations"
on public.carbon_calculations for all
to authenticated
using (public.current_user_role() = 'admin')
with check (public.current_user_role() = 'admin');

drop policy if exists "owner manage own carbon calculations" on public.carbon_calculations;
create policy "owner manage own carbon calculations"
on public.carbon_calculations for all
to authenticated
using (
  public.current_user_role() = 'owner'
  and exists (
    select 1 from public.forest_projects project
    where project.id = carbon_calculations.project_id
      and project.owner_id = public.current_user_owner_id()
  )
)
with check (
  public.current_user_role() = 'owner'
  and exists (
    select 1 from public.forest_projects project
    where project.id = carbon_calculations.project_id
      and project.owner_id = public.current_user_owner_id()
  )
);

drop policy if exists "authenticated read files" on public.files;
drop policy if exists "scoped read files" on public.files;
create policy "scoped read files"
on public.files for select
to authenticated
using (
  public.current_user_role() = 'admin'
  or owner_id = public.current_user_owner_id()
  or exists (
    select 1 from public.forest_projects project
    where project.id = files.project_id
      and project.owner_id = public.current_user_owner_id()
  )
);

drop policy if exists "owner manage own files" on public.files;
create policy "owner manage own files"
on public.files for all
to authenticated
using (
  public.current_user_role() = 'owner'
  and (
    owner_id = public.current_user_owner_id()
    or exists (
      select 1 from public.forest_projects project
      where project.id = files.project_id
        and project.owner_id = public.current_user_owner_id()
    )
  )
)
with check (
  public.current_user_role() = 'owner'
  and (
    owner_id = public.current_user_owner_id()
    or exists (
      select 1 from public.forest_projects project
      where project.id = files.project_id
        and project.owner_id = public.current_user_owner_id()
    )
  )
);

create or replace function public.notify_qlr_activity()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  notification_title text;
  notification_message text;
  notification_type text;
  target_owner_id uuid;
begin
  if tg_table_name = 'logbooks' then
    notification_title := 'Nhật ký mới';
    notification_message := coalesce(new.description, 'Có nhật ký hiện trường mới.');
    notification_type := 'logbook';
    select owner_id into target_owner_id from public.forest_projects where id = new.project_id;
  elsif tg_table_name = 'forest_projects' then
    notification_title := 'Dự án mới';
    notification_message := 'Dự án ' || coalesce(new.project_name, '') || ' vừa được tạo.';
    notification_type := 'project';
    target_owner_id := new.owner_id;
  elsif tg_table_name = 'files' then
    notification_title := 'Hồ sơ mới';
    notification_message := 'Tệp ' || coalesce(new.file_name, '') || ' vừa được tải lên.';
    notification_type := 'profile';
    target_owner_id := new.owner_id;
  else
    notification_title := 'Tài khoản mới';
    notification_message := 'Tài khoản ' || coalesce(new.email, '') || ' vừa được tạo.';
    notification_type := 'profile';
    target_owner_id := new.owner_id;
  end if;

  insert into public.notifications (user_id, title, message, type)
  select profile.id, notification_title, notification_message, notification_type
  from public.profiles profile
  where profile.status = 'active'
    and (
      profile.role = 'admin'
      or (target_owner_id is not null and profile.role = 'owner' and profile.owner_id = target_owner_id)
    );
  return new;
end;
$$;

drop trigger if exists notify_logbook_activity on public.logbooks;
create trigger notify_logbook_activity after insert on public.logbooks
for each row execute function public.notify_qlr_activity();

drop trigger if exists notify_project_activity on public.forest_projects;
create trigger notify_project_activity after insert on public.forest_projects
for each row execute function public.notify_qlr_activity();

drop trigger if exists notify_file_activity on public.files;
create trigger notify_file_activity after insert on public.files
for each row execute function public.notify_qlr_activity();

drop trigger if exists notify_profile_activity on public.profiles;
create trigger notify_profile_activity after insert on public.profiles
for each row execute function public.notify_qlr_activity();

drop policy if exists "Authenticated upload logbook images" on storage.objects;
create policy "Authenticated upload logbook images"
on storage.objects
for insert
to authenticated
with check (
  bucket_id = 'logbook-images'
  and (storage.foldername(name))[1] = 'logbooks'
  and (storage.foldername(name))[2] = auth.uid()::text
);

drop policy if exists "Authenticated update own logbook images" on storage.objects;
create policy "Authenticated update own logbook images"
on storage.objects
for update
to authenticated
using (
  bucket_id = 'logbook-images'
  and (storage.foldername(name))[1] = 'logbooks'
  and (storage.foldername(name))[2] = auth.uid()::text
)
with check (
  bucket_id = 'logbook-images'
  and (storage.foldername(name))[1] = 'logbooks'
  and (storage.foldername(name))[2] = auth.uid()::text
);
