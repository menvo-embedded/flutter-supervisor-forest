-- Demo users must be created first in Supabase Dashboard:
-- Authentication > Users > Add user
-- admin@qlr.vn / 123456
-- owner@qlr.vn / 123456
-- worker@qlr.vn / 123456
--
-- Then replace the UUID values below with the generated auth user IDs.

do $$
declare
  admin_user_id uuid := '3b81a154-ef07-4601-9082-d687ea3857b4';
  owner_user_id uuid := 'b49566de-a36e-4c23-abad-9c7054cf2d74';
  worker_user_id uuid := 'c9c8ccac-cd38-4f84-a4bf-471c3e4a6953';
  demo_owner_id uuid;
  demo_project_id uuid;
begin
  insert into public.forest_owners (
    owner_code, owner_name, type, identity_no, address, phone, email
  ) values (
    'OWN-0001',
    'Nguyen Van A',
    'individual',
    '123456789012',
    'Lam Dong, Viet Nam',
    '0901234567',
    'owner@qlr.vn'
  )
  on conflict (owner_code) do update set owner_name = excluded.owner_name
  returning id into demo_owner_id;

  if demo_owner_id is null then
    select id into demo_owner_id from public.forest_owners where owner_code = 'OWN-0001';
  end if;

  insert into public.profiles (id, email, full_name, phone, role, status, owner_id)
  values
    (admin_user_id, 'admin@qlr.vn', 'Admin Platform', '0900000001', 'admin', 'active', null),
    (owner_user_id, 'owner@qlr.vn', 'Nguyen Van A', '0900000002', 'owner', 'active', demo_owner_id),
    (worker_user_id, 'worker@qlr.vn', 'Tran Thi B', '0900000003', 'worker', 'active', demo_owner_id)
  on conflict (id) do update set
    email = excluded.email,
    full_name = excluded.full_name,
    phone = excluded.phone,
    role = excluded.role,
    status = excluded.status,
    owner_id = excluded.owner_id;

  insert into public.forest_projects (
    owner_id, project_code, project_name, province, district, commune,
    forest_type, tree_species, year_planted, status, area_ha
  ) values (
    demo_owner_id,
    'PRJ-0001',
    'Dak Lak Project 01',
    'Dak Lak',
    'Krong Bong',
    'Hoa Phong',
    'Rung trong',
    'Keo',
    2020,
    'active',
    1250.50
  )
  on conflict (project_code) do update set project_name = excluded.project_name
  returning id into demo_project_id;

  if demo_project_id is null then
    select id into demo_project_id from public.forest_projects where project_code = 'PRJ-0001';
  end if;

  insert into public.carbon_factors (species, factor)
  values
    ('Keo', 0.48),
    ('Bach dan', 0.47),
    ('Thong', 0.50)
  on conflict (species) do update set factor = excluded.factor;

  insert into public.logbooks (
    user_id, owner_id, project_id, work_type, description,
    latitude, longitude, photo_urls, is_synced
  ) values (
    worker_user_id,
    demo_owner_id,
    demo_project_id,
    'care',
    'Cham soc cay va kiem tra hien truong mau.',
    12.345678,
    108.234567,
    '{}',
    true
  );

  insert into public.checkins (
    user_id, project_id, latitude, longitude, checked_at
  ) values (
    worker_user_id,
    demo_project_id,
    12.345678,
    108.234567,
    now()
  );

  insert into public.inventory_plots (
    project_id, plot_code, latitude, longitude, area
  ) values (
    demo_project_id,
    'PLT-0001',
    12.345678,
    108.234567,
    500
  );

  insert into public.notifications (user_id, title, message, type)
  values
    (admin_user_id, 'Logbook moi', 'Worker vua gui logbook mau.', 'logbook'),
    (owner_user_id, 'Du an dang hoat dong', 'Dak Lak Project 01 da san sang.', 'project');
end $$;
