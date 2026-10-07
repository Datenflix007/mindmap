-- JenaCraft Collaborative Mindmap · Supabase schema
-- Im Supabase SQL Editor vollständig ausführen.
-- Enthält sichere RPC-Funktionen sowie „Auf Vorlage zurücksetzen“.

create extension if not exists pgcrypto with schema extensions;

create table if not exists public.mm_sessions (
  id uuid primary key default extensions.gen_random_uuid(),
  code text unique not null,
  title text not null check (char_length(title) between 1 and 120),
  template_key text not null default 'custom',
  moderator_secret_hash text not null,
  is_open boolean not null default true,
  collected_at timestamptz,
  created_at timestamptz not null default now()
);

create table if not exists public.mm_branches (
  id uuid primary key default extensions.gen_random_uuid(),
  session_id uuid not null references public.mm_sessions(id) on delete cascade,
  title text not null check (char_length(title) between 1 and 80),
  sort_order int not null default 0
);

create table if not exists public.mm_nodes (
  id uuid primary key default extensions.gen_random_uuid(),
  session_id uuid not null references public.mm_sessions(id) on delete cascade,
  group_no int not null check (group_no between 1 and 99),
  branch_id uuid not null references public.mm_branches(id) on delete cascade,
  parent_id uuid references public.mm_nodes(id) on delete cascade,
  text text not null check (char_length(text) between 1 and 240),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists mm_nodes_session_idx on public.mm_nodes(session_id);
create index if not exists mm_nodes_group_idx on public.mm_nodes(session_id, group_no);

alter table public.mm_sessions enable row level security;
alter table public.mm_branches enable row level security;
alter table public.mm_nodes enable row level security;

revoke all on public.mm_sessions from anon, authenticated;
revoke all on public.mm_branches from anon, authenticated;
revoke all on public.mm_nodes from anon, authenticated;

create or replace function public.mm_make_code()
returns text
language plpgsql
security definer
set search_path=public, extensions
as $$
declare c text;
begin
  loop
    c := upper(substr(encode(extensions.gen_random_bytes(8),'hex'),1,6));
    exit when not exists(select 1 from public.mm_sessions where code=c);
  end loop;
  return c;
end $$;

create or replace function public.mm_token_ok(p_session_id uuid, p_token text)
returns boolean
language sql
stable
security definer
set search_path=public, extensions
as $$
  select exists(
    select 1 from public.mm_sessions
    where id=p_session_id
      and moderator_secret_hash = encode(extensions.digest(coalesce(p_token,''),'sha256'),'hex')
  );
$$;

create or replace function public.create_session(p_title text, p_template_key text, p_branch_titles text[])
returns jsonb
language plpgsql
security definer
set search_path=public, extensions
as $$
declare s public.mm_sessions; tok text; b text; i int:=0;
begin
  if p_title is null or btrim(p_title)='' then raise exception 'Titel fehlt'; end if;
  if array_length(p_branch_titles,1) is null then raise exception 'Mindestens ein Ast wird benötigt'; end if;
  tok := encode(extensions.gen_random_bytes(24),'hex');
  insert into public.mm_sessions(code,title,template_key,moderator_secret_hash)
  values(
    public.mm_make_code(),
    left(btrim(p_title),120),
    coalesce(nullif(p_template_key,''),'custom'),
    encode(extensions.digest(tok,'sha256'),'hex')
  ) returning * into s;
  foreach b in array p_branch_titles loop
    if btrim(b)<>'' then
      insert into public.mm_branches(session_id,title,sort_order)
      values(s.id,left(btrim(b),80),i);
      i:=i+1;
    end if;
  end loop;
  return jsonb_build_object(
    'session',jsonb_build_object('id',s.id,'code',s.code,'title',s.title,'is_open',s.is_open,'created_at',s.created_at),
    'moderator_token',tok
  );
end $$;

create or replace function public.get_session_public(p_code text)
returns jsonb
language plpgsql
security definer
set search_path=public, extensions
as $$
declare s public.mm_sessions;
begin
  select * into s from public.mm_sessions where code=upper(btrim(p_code));
  if not found then return null; end if;
  return jsonb_build_object(
    'session',jsonb_build_object('id',s.id,'code',s.code,'title',s.title,'is_open',s.is_open,'created_at',s.created_at),
    'branches',coalesce((select jsonb_agg(jsonb_build_object('id',id,'title',title,'sort_order',sort_order) order by sort_order) from public.mm_branches where session_id=s.id),'[]'::jsonb)
  );
end $$;

create or replace function public.get_group_nodes(p_code text,p_group_no int)
returns jsonb
language plpgsql
security definer
set search_path=public, extensions
as $$
declare sid uuid;
begin
  select id into sid from public.mm_sessions where code=upper(btrim(p_code));
  if sid is null then raise exception 'Session nicht gefunden'; end if;
  return coalesce((
    select jsonb_agg(jsonb_build_object(
      'id',id,'branch_id',branch_id,'parent_id',parent_id,'group_no',group_no,
      'text',text,'created_at',created_at,'updated_at',updated_at
    ) order by created_at)
    from public.mm_nodes where session_id=sid and group_no=p_group_no
  ),'[]'::jsonb);
end $$;

create or replace function public.add_node(p_code text,p_group_no int,p_branch_id uuid,p_parent_id uuid,p_text text)
returns jsonb
language plpgsql
security definer
set search_path=public, extensions
as $$
declare s public.mm_sessions; n public.mm_nodes;
begin
  select * into s from public.mm_sessions where code=upper(btrim(p_code));
  if not found then raise exception 'Session nicht gefunden'; end if;
  if not s.is_open then raise exception 'Die Session ist gesperrt'; end if;
  if p_group_no<1 or p_group_no>99 then raise exception 'Ungültige Gruppe'; end if;
  if p_text is null or btrim(p_text)='' then raise exception 'Text fehlt'; end if;
  if not exists(select 1 from public.mm_branches where id=p_branch_id and session_id=s.id) then raise exception 'Ungültiger Ast'; end if;
  if p_parent_id is not null and not exists(
    select 1 from public.mm_nodes
    where id=p_parent_id and session_id=s.id and group_no=p_group_no and branch_id=p_branch_id
  ) then raise exception 'Ungültiger Elternknoten'; end if;
  insert into public.mm_nodes(session_id,group_no,branch_id,parent_id,text)
  values(s.id,p_group_no,p_branch_id,p_parent_id,left(btrim(p_text),240)) returning * into n;
  return to_jsonb(n);
end $$;

create or replace function public.update_node(p_code text,p_group_no int,p_node_id uuid,p_text text)
returns void
language plpgsql
security definer
set search_path=public, extensions
as $$
declare sid uuid; open_state boolean;
begin
  select id,is_open into sid,open_state from public.mm_sessions where code=upper(btrim(p_code));
  if sid is null then raise exception 'Session nicht gefunden'; end if;
  if not open_state then raise exception 'Session nicht offen'; end if;
  if p_text is null or btrim(p_text)='' then raise exception 'Text fehlt'; end if;
  update public.mm_nodes set text=left(btrim(p_text),240),updated_at=now()
  where id=p_node_id and session_id=sid and group_no=p_group_no;
  if not found then raise exception 'Knoten nicht gefunden'; end if;
end $$;

create or replace function public.delete_node(p_code text,p_group_no int,p_node_id uuid)
returns void
language plpgsql
security definer
set search_path=public, extensions
as $$
declare sid uuid; open_state boolean;
begin
  select id,is_open into sid,open_state from public.mm_sessions where code=upper(btrim(p_code));
  if sid is null then raise exception 'Session nicht gefunden'; end if;
  if not open_state then raise exception 'Session nicht offen'; end if;
  delete from public.mm_nodes where id=p_node_id and session_id=sid and group_no=p_group_no;
  if not found then raise exception 'Knoten nicht gefunden'; end if;
end $$;

create or replace function public.moderator_snapshot(p_code text,p_moderator_token text)
returns jsonb
language plpgsql
security definer
set search_path=public, extensions
as $$
declare s public.mm_sessions;
begin
  select * into s from public.mm_sessions where code=upper(btrim(p_code));
  if not found or not public.mm_token_ok(s.id,p_moderator_token) then raise exception 'Moderator-Zugriff verweigert'; end if;
  return jsonb_build_object(
    'session',jsonb_build_object(
      'id',s.id,'code',s.code,'title',s.title,'template_key',s.template_key,
      'is_open',s.is_open,'collected_at',s.collected_at,'created_at',s.created_at
    ),
    'branches',coalesce((select jsonb_agg(jsonb_build_object('id',id,'title',title,'sort_order',sort_order) order by sort_order) from public.mm_branches where session_id=s.id),'[]'::jsonb),
    'nodes',coalesce((select jsonb_agg(jsonb_build_object(
      'id',id,'branch_id',branch_id,'parent_id',parent_id,'group_no',group_no,
      'text',text,'created_at',created_at,'updated_at',updated_at
    ) order by created_at) from public.mm_nodes where session_id=s.id),'[]'::jsonb)
  );
end $$;

create or replace function public.set_session_open(p_code text,p_moderator_token text,p_is_open boolean)
returns void
language plpgsql
security definer
set search_path=public, extensions
as $$
declare s public.mm_sessions;
begin
  select * into s from public.mm_sessions where code=upper(btrim(p_code));
  if not found or not public.mm_token_ok(s.id,p_moderator_token) then raise exception 'Moderator-Zugriff verweigert'; end if;
  update public.mm_sessions set is_open=p_is_open where id=s.id;
end $$;

create or replace function public.mark_collected(p_code text,p_moderator_token text)
returns void
language plpgsql
security definer
set search_path=public, extensions
as $$
declare s public.mm_sessions;
begin
  select * into s from public.mm_sessions where code=upper(btrim(p_code));
  if not found or not public.mm_token_ok(s.id,p_moderator_token) then raise exception 'Moderator-Zugriff verweigert'; end if;
  update public.mm_sessions set collected_at=now() where id=s.id;
end $$;

-- Setzt die Session auf ihre Vorlage zurück.
-- JenaCraft: Titel + vier Standardäste werden wiederhergestellt.
-- Custom: Beiträge werden gelöscht, vorhandene Aststruktur bleibt bestehen.
create or replace function public.reset_session_to_template(p_code text,p_moderator_token text)
returns jsonb
language plpgsql
security definer
set search_path=public, extensions
as $$
declare s public.mm_sessions;
begin
  select * into s from public.mm_sessions where code=upper(btrim(p_code));
  if not found or not public.mm_token_ok(s.id,p_moderator_token) then
    raise exception 'Moderator-Zugriff verweigert';
  end if;

  -- Beiträge zuerst löschen; dadurch gibt es keine Fremdschlüsselkonflikte.
  delete from public.mm_nodes where session_id=s.id;

  if s.template_key='jenacraft' then
    delete from public.mm_branches where session_id=s.id;

    update public.mm_sessions
      set title='Must haves und No Gos JenaCraft',
          is_open=true,
          collected_at=null
      where id=s.id;

    insert into public.mm_branches(session_id,title,sort_order) values
      (s.id,'Must Haves',0),
      (s.id,'No Gos',1),
      (s.id,'Anmerkung',2),
      (s.id,'Gern besuchte Orte',3);

    return jsonb_build_object(
      'ok',true,
      'mode','jenacraft',
      'message','Beiträge gelöscht und JenaCraft-Vorlage wiederhergestellt.'
    );
  else
    update public.mm_sessions
      set is_open=true,
          collected_at=null
      where id=s.id;

    return jsonb_build_object(
      'ok',true,
      'mode','custom',
      'message','Beiträge gelöscht. Die benutzerdefinierte Aststruktur wurde beibehalten.'
    );
  end if;
end $$;

-- Browserzugriff nur auf die benötigten RPC-Funktionen.
grant execute on function public.create_session(text,text,text[]) to anon, authenticated;
grant execute on function public.get_session_public(text) to anon, authenticated;
grant execute on function public.get_group_nodes(text,int) to anon, authenticated;
grant execute on function public.add_node(text,int,uuid,uuid,text) to anon, authenticated;
grant execute on function public.update_node(text,int,uuid,text) to anon, authenticated;
grant execute on function public.delete_node(text,int,uuid) to anon, authenticated;
grant execute on function public.moderator_snapshot(text,text) to anon, authenticated;
grant execute on function public.set_session_open(text,text,boolean) to anon, authenticated;
grant execute on function public.mark_collected(text,text) to anon, authenticated;
grant execute on function public.reset_session_to_template(text,text) to anon, authenticated;

-- Hilfsfunktionen nicht direkt aus dem Browser aufrufen.
revoke execute on function public.mm_make_code() from public, anon, authenticated;
revoke execute on function public.mm_token_ok(uuid,text) from public, anon, authenticated;
