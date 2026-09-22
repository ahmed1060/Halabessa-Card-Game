create or replace function halabessa.claim_daily_reward(
  p_uid text,
  p_email text,
  p_display_name text,
  p_today date
) returns table(streak integer, coins integer, diamonds integer, claim_date date)
language plpgsql
security definer
set search_path = halabessa, pg_temp
as $$
declare
  prior jsonb;
  prior_date date;
  prior_streak integer;
  next_streak integer;
  reward_coins integer;
  reward_diamonds integer;
begin
  insert into halabessa.user_profiles (firebase_uid, email, display_name)
  values (p_uid, p_email, coalesce(nullif(left(p_display_name, 64), ''), 'Player'))
  on conflict (firebase_uid) do nothing;

  select daily_reward into prior
  from halabessa.user_profiles
  where firebase_uid = p_uid
  for update;

  prior_date := nullif(prior ->> 'lastClaimDate', '')::date;
  prior_streak := coalesce((prior ->> 'streak')::integer, 0);
  if prior_date = p_today then
    raise exception 'already_claimed' using errcode = 'P0001';
  end if;
  next_streak := case when prior_date = p_today - 1
    then (prior_streak % 7) + 1 else 1 end;
  reward_coins := (array[100, 200, 300, 400, 500, 750, 1500])[next_streak];
  reward_diamonds := (array[0, 0, 1, 0, 2, 0, 5])[next_streak];

  update halabessa.user_profiles set
    coins = coins + reward_coins,
    diamonds = diamonds + reward_diamonds,
    daily_reward = jsonb_build_object('lastClaimDate', p_today::text, 'streak', next_streak),
    updated_at = now()
  where firebase_uid = p_uid;
  return query select next_streak, reward_coins, reward_diamonds, p_today;
end;
$$;

revoke all on function halabessa.claim_daily_reward(text, text, text, date) from public, anon, authenticated;
