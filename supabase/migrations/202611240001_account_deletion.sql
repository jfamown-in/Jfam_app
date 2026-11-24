-- Enable authenticated customers to permanently delete their own account (Google Play policy requirement).

begin;

create or replace function public.delete_my_account()
returns jsonb
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  v_user_id uuid := auth.uid();
begin
  if v_user_id is null then
    raise exception 'authentication required';
  end if;

  if to_regclass('public.saved_addresses') is not null then
    delete from public.saved_addresses where user_id = v_user_id;
  end if;

  if to_regclass('public.saved_upis') is not null then
    delete from public.saved_upis where user_id = v_user_id;
  end if;

  if to_regclass('public.wishlist') is not null then
    delete from public.wishlist where user_id = v_user_id;
  end if;

  if to_regclass('public.cart_items') is not null then
    delete from public.cart_items where user_id = v_user_id;
  end if;

  if to_regclass('public.notifications') is not null then
    delete from public.notifications where user_id = v_user_id;
  end if;

  if to_regclass('public.profiles') is not null then
    delete from public.profiles where id = v_user_id;
  end if;

  -- Deleting the Supabase Auth user cascades to orders, order_items,
  -- wallet_transactions, checkout_attempts, and payment_attempts.
  delete from auth.users where id = v_user_id;

  return jsonb_build_object(
    'deleted', true,
    'userId', v_user_id
  );
end;
$$;

revoke all on function public.delete_my_account() from public;
grant execute on function public.delete_my_account() to authenticated;

notify pgrst, 'reload schema';

commit;
