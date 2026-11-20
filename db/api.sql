-- Rôle de connexion de PostgREST (comme sur Supabase) : il ne fait que basculer vers anon.
do $$ begin
  if not exists (select 1 from pg_roles where rolname = 'authenticator') then
    create role authenticator login password 'demo' noinherit;
  end if;
end $$;
grant anon to authenticator;
