// SPDX-FileCopyrightText: 2021 TQ Tezos
// SPDX-License-Identifier: LicenseRef-MIT-TQ

// Corresponds to Proposal.hs module

#include "types.mligo"
#include "common.mligo"
#include "token/fa2.mligo"
#include "token.mligo"
#include "permit.mligo"

// -----------------------------------------------------------------
// Helper
// -----------------------------------------------------------------

[@inline]
let to_proposal_key (propose_params, sender_addr : propose_params * address): proposal_key =
  Crypto.blake2b (Bytes.pack (propose_params, sender_addr))

[@inline]
let check_if_proposal_exist (proposal_key, store : proposal_key * storage): proposal =
  match Map.find_opt proposal_key store.proposals with
    Some p -> p
  | None ->
      (failwith("PROPOSAL_NOT_EXIST") : proposal)

// Gets the current period counting how many `voting_period` s have passed since
// the 'started_on` timestamp. The periods start from zero index.
let get_current_period_num(start_time, vp_length : timestamp * voting_period) : nat =
  match is_nat((Tezos.now - start_time) : int) with
  | Some (elapsed_time) -> elapsed_time/vp_length.length
  | None -> ([%Michelson ({| { FAILWITH } |} : string * unit -> nat)]
      ("STARTED_ON_IN_FUTURE", ()))

[@inline]
let ensure_proposal_voting_period (proposal, voting_period, store : proposal * voting_period * storage): storage =
  let current_period = get_current_period_num(store.start_time, voting_period) in
  if current_period = (proposal.period_num + 1n)
  then store
  else (failwith("VOTING_PERIOD_OVER") : storage)

// Checks that a given period number is a proposing period
// Only odd period numbers are proposing periods, in which a proposal can be
// submitted.
let ensure_proposing_period(period_num, store : nat * storage): storage =
  if (period_num mod 2n) = 1n
  then store
  else (failwith("NOT_PROPOSING_PERIOD") : storage)

[@inline]
let ensure_proposal_is_unique (propose_params, store : propose_params * storage): proposal_key =
  let proposal_key = to_proposal_key(propose_params, Tezos.sender) in
  if Map.mem proposal_key store.proposals
    then (failwith("PROPOSAL_NOT_UNIQUE") : proposal_key)
    else proposal_key

let quorum_denominator_int = int(quorum_denominator)
  // Hopefuly this will be optimized by the compiler and does not actually
  // call `int` for every access to this value

// Multiply two quorum_fractions
//
// We store fractions by storing only the numerator and denominator is always
// assumed to be quorum_denominator. So here qt_1, actually represents the
// value qt_1.numerator/ quorum_denominator and qt_2 represents the value
// qt_2.numerator/ quorum_denominator. So the product of the two is
// qt_1.numerator * qt_2.numerator / (quorum_denominator *
// quorum_denominator).  But since we store x as x * quorum_denominator,
// the result here would be qt_1.numerator * qt_2.numerator /
// quorum_denominator. This will also retain the required precision of
// 1/quorum_denominator.
[@inline]
let fmul(qt_1, qt_2 : quorum_fraction * quorum_fraction): quorum_fraction =
   { numerator = (qt_1.numerator * qt_2.numerator) / quorum_denominator_int }

// Divide the first fraction by the second Here qt_1, actually represents the
// value qt_1.numerator/ quorum_denominator and qt_2 represents the value
// qt_2.numerator/ quorum_denominator. So the division can be expressed as
// (qt_1.numerator * quorum_denominator) / (quorum_denominator *
// qt_2.numerator) But since we store x as x * quorum_denominator, the result
// here would be (qt_1.numerator * quorum_denominator_int) / qt_2.numerator
[@inline]
let fdiv(qt_1, qt_2 : quorum_fraction * quorum_fraction): quorum_fraction =
  { numerator = (qt_1.numerator * quorum_denominator_int) / qt_2.numerator }

[@inline]
let fadd(qt_1, qt_2 : quorum_fraction * quorum_fraction): quorum_fraction =
  {numerator = qt_1.numerator + qt_2.numerator }

[@inline]
let fsub(qt_1, qt_2 : quorum_fraction * quorum_fraction): quorum_fraction =
  { numerator = qt_1.numerator - qt_2.numerator }

[@inline]
let bound_qt (qt, min_qt, max_qt : quorum_fraction * quorum_fraction * quorum_fraction)
    : quorum_fraction =
  if (qt.numerator > max_qt.numerator) then max_qt else
    if (qt.numerator < min_qt.numerator) then min_qt else qt

// -----------------------------------------------------------------
// Freeze history operations
// -----------------------------------------------------------------

let add_frozen_fh (amt, fh : nat * address_freeze_history)
    : address_freeze_history =
  { fh with current_unstaked = fh.current_unstaked + amt }

let sub_frozen_fh (amt, fh : nat * address_freeze_history)
    : address_freeze_history =
  match is_nat(fh.past_unstaked - amt) with
  | None ->
      ([%Michelson ({| { FAILWITH } |} : (string * unit) -> address_freeze_history)]
        ( "NOT_ENOUGH_FROZEN_TOKENS", ()) : address_freeze_history)
  | Some new_amt ->
      { fh with past_unstaked = new_amt }

let stake_frozen_fh (amt, fh : nat * address_freeze_history): address_freeze_history =
  let fh = sub_frozen_fh(amt, fh) in
  { fh with staked = fh.staked + amt }

let unstake_frozen_fh (amt, fh : nat * address_freeze_history)
    : address_freeze_history =
  match is_nat(fh.staked - amt) with
  | None ->
      ([%Michelson ({| { FAILWITH } |} : (string * unit) -> address_freeze_history)]
        ("NOT_ENOUGH_STAKED_TOKENS", ()) : address_freeze_history)
  | Some new_amt ->
     // Adding to past_unstaked should be fine since as of now, the staked tokens have to be from
      // past periods.
      { fh with staked = new_amt; past_unstaked = fh.past_unstaked + amt }

// Update a possibly outdated freeze_history for the current period
let update_fh (current_period, freeze_history : nat * address_freeze_history): address_freeze_history =
  if freeze_history.current_period_num < current_period
    then
      { current_period_num = current_period
      ; staked = freeze_history.staked
      ; current_unstaked = 0n
      ; past_unstaked = freeze_history.current_unstaked + freeze_history.past_unstaked
      }
    else freeze_history

// -----------------------------------------------------------------
// Propose
// -----------------------------------------------------------------

[@inline]
let check_is_proposal_valid (config, propose_params, store : config * propose_params * storage): storage =
  if config.proposal_check (propose_params, store.extra)
    then store
    else (failwith("FAIL_PROPOSAL_CHECK") : storage)

[@inline]
let check_proposal_limit_reached (config, store : config * storage): storage =
  if config.max_proposals <= List.length store.proposal_key_list_sort_by_date
    then (failwith("MAX_PROPOSALS_REACHED") : storage)
    else store

let freeze_on_ledger (tokens, addr, ledger, total_supply, frozen_token_id, governance_token : nat * address * ledger * total_supply * token_id * governance_token)
    : (operation * ledger * total_supply) =
  // Call transfer on token_contract to transfer `token` number of
  // tokens from `addr` to the address of this contract.
  let param = { from_ = addr; txs = [{ amount = tokens; to_ = Tezos.self_address; token_id = governance_token.token_id }]} in
  let operation = make_transfer_on_token ([param], governance_token.address) in

  // Once this contract is credited on the token contract, we can mint frozen tokens
  // to credit the `addr` address here.
  let (ledger, total_supply) = credit_to (tokens, addr, frozen_token_id, ledger, total_supply) in
  (operation, ledger, total_supply)

[@inline]
let period_to_cycle (p: nat): nat = (p + 1n) / 2n

let stake_tk(token_amount, addr, voting_period, store : nat * address * voting_period * storage): storage =
  let current_period = get_current_period_num(store.start_time, voting_period) in
  let current_cycle = period_to_cycle(current_period) in
  let new_cycle_staked = store.quorum_threshold_at_cycle.staked + token_amount in
  let new_freeze_history = match Big_map.find_opt addr store.freeze_history with
    | Some fh ->
        let fh = update_fh(current_period, fh) in
        let fh = stake_frozen_fh(token_amount, fh) in
        Big_map.update addr (Some(fh)) store.freeze_history
    | None ->
      if token_amount = 0n
      then store.freeze_history
      else ([%Michelson ({| { FAILWITH } |} : (string * unit) -> freeze_history)]
              ("NOT_ENOUGH_FROZEN_TOKENS", ()) : freeze_history)
  in { store with freeze_history = new_freeze_history; quorum_threshold_at_cycle = {store.quorum_threshold_at_cycle with staked = new_cycle_staked } }

[@inline]
let unfreeze_on_ledger (tokens, addr, ledger, total_supply, frozen_token_id, governance_token : nat * address * ledger * total_supply * token_id * governance_token): (operation * ledger * total_supply) =
  // Call transfer on token_contract to transfer `token` number of
  // tokens from `addr` to the address of this contract.
  let param = { from_ = Tezos.self_address; txs = [{ amount = tokens; to_ = addr; token_id = governance_token.token_id }]} in
  let operation = make_transfer_on_token ([param], governance_token.address) in

  // Once this contract is credited on the token contract, we can burn frozen tokens
  // to debit the `addr` address here.
  let (ledger, total_supply) = debit_from (tokens, addr, frozen_token_id, ledger, total_supply) in
  (operation, ledger, total_supply)

let add_proposal (propose_params, voting_period, store : propose_params * voting_period * storage): storage =
  let proposal_key = ensure_proposal_is_unique (propose_params, store) in
  let current_period = get_current_period_num(store.start_time, voting_period) in
  let store = ensure_proposing_period(current_period, store) in
  let timestamp = Tezos.now in
  let proposal : proposal =
    { upvotes = 0n
    ; downvotes = 0n
    ; start_date = timestamp
    ; period_num = current_period
    ; metadata = propose_params.proposal_metadata
    ; proposer = Tezos.sender
    ; proposer_frozen_token = propose_params.frozen_token
    ; voters = ([] : voter list)
    ; quorum_threshold = store.quorum_threshold_at_cycle.quorum_threshold
    } in
  { store with
    proposals =
      Map.add proposal_key proposal store.proposals
  ; proposal_key_list_sort_by_date =
      Set.add (timestamp, proposal_key) store.proposal_key_list_sort_by_date
  }

// -----------------------------------------------------------------
// Vote
// -----------------------------------------------------------------

let submit_vote (proposal, vote_param, author, voting_period, store : proposal * vote_param * address * voting_period * storage): storage =
  let proposal_key = vote_param.proposal_key in

  let proposal =
    if vote_param.vote_type
      then { proposal with upvotes = proposal.upvotes + vote_param.vote_amount }
      else { proposal with downvotes = proposal.downvotes + vote_param.vote_amount }
    in
  let voter =
    { voter_address = author
    ; vote_amount = vote_param.vote_amount
    ; vote_type = vote_param.vote_type
    } in
  let proposal =
    { proposal with
      voters = voter :: proposal.voters
    } in
  let store = stake_tk(vote_param.vote_amount, author, voting_period, store) in
  { store with proposals = Map.add proposal_key proposal store.proposals }

[@inline]
let check_vote_limit_reached
    (config, proposal, vote_param : config * proposal * vote_param): vote_param =
  if config.max_votes < proposal.upvotes + proposal.downvotes + vote_param.vote_amount
    then (failwith("MAX_VOTES_REACHED") : vote_param)
    else vote_param

let vote(votes, config, store : vote_param_permited list * config * storage): return =
  let accept_vote = fun (store, pp : storage * vote_param_permited) ->
    let (param, author, store) = verify_permit_protected_vote (pp, store) in
    let proposal = check_if_proposal_exist (param.proposal_key, store) in
    let vote_param = check_vote_limit_reached (config, proposal, param) in
    let store = ensure_proposal_voting_period (proposal, config.voting_period, store) in
    let store = submit_vote (proposal, vote_param, author, config.voting_period, store) in
    store
    in
  ( ([] : operation list)
  , List.fold accept_vote votes store
  )

// -----------------------------------------------------------------
// Admin entrypoints
// -----------------------------------------------------------------

[@inline]
let burn_frozen_token (tokens, addr, store : nat * address * storage): storage =
  let (ledger, total_supply) = debit_from(tokens, addr, store.frozen_token_id, store.ledger, store.total_supply)
  in {store with ledger = ledger; total_supply = total_supply}

// Burn up to desired_burn_amount of tokens. The desired burn amount comprises
// slash amount calculated by "config.rejected_proposal_return_value" and
// the fixed fee payed for the proposal. The case when the desired burn amount
// is larger than the available frozen tokens is possible because the contract
// administrator can transfer the proposer's frozen tokens.
[@inline]
let burn_what_possible (desired_burn_amount, frozen_tokens, addr, store : nat * nat * address * storage): storage =
  let to_burn =
    if frozen_tokens >= desired_burn_amount
    then desired_burn_amount
    else frozen_tokens
  in burn_frozen_token (to_burn, addr, store)

let unstake_tk(token_amount, addr, voting_period, store : nat * address * voting_period * storage): storage =
  let current_period = get_current_period_num(store.start_time, voting_period) in
  match Big_map.find_opt addr store.freeze_history with
    | Some(fh) ->
        let fh = update_fh(current_period, fh) in
        let fh = unstake_frozen_fh(token_amount, fh) in
        let new_freze_history = Big_map.update addr (Some(fh)) store.freeze_history in
        { store with freeze_history = new_freze_history }
    | None -> ([%Michelson ({| { FAILWITH } |} : (string * unit) -> storage)]
          ("NOT_ENOUGH_STAKED_TOKENS", ()) : storage)

let unfreeze_proposer_and_voter_token
  (rejected_proposal_return, is_accepted, proposal, voting_period, fixed_fee, store :
    (proposal * contract_extra -> nat) * bool * proposal * voting_period * nat * storage): storage =
  // unfreeze_proposer_token
  let (tokens, store) =
    if is_accepted
    then (proposal.proposer_frozen_token + fixed_fee, store)
    else
      let slash_amount = rejected_proposal_return (proposal, store.extra) in
      let frozen_tokens = proposal.proposer_frozen_token + fixed_fee in
      let desired_burn_amount = slash_amount + fixed_fee in
      let store =
        burn_what_possible
          (desired_burn_amount, frozen_tokens, proposal.proposer, store) in
      let tokens =
            match Michelson.is_nat(frozen_tokens - desired_burn_amount) with
              Some value -> value
            | None -> 0n
            in
      (tokens, store)
    in
  let store = unstake_tk(tokens, proposal.proposer, voting_period, store) in

  // unfreeze_voter_token
  let do_unfreeze = fun
        ( store, voter
        : storage * voter
        ) -> unstake_tk(voter.vote_amount, voter.voter_address, voting_period, store) in

  List.fold do_unfreeze proposal.voters store

[@inline]
let is_voting_period_over (proposal, voting_period, store : proposal * voting_period * storage): bool =
  let current_period = get_current_period_num(store.start_time, voting_period) in
  current_period > proposal.period_num + 1n

[@inline]
let is_time_reached (proposal, sec : proposal * seconds): bool =
  Tezos.now > proposal.start_date + int(sec)

[@inline]
let frozen_total_supply(store : storage): nat =
    match Map.find_opt store.frozen_token_id store.total_supply with
    | Some v -> v
    | None -> ((failwith "BAD_STATE") : nat)

[@inline]
let do_total_vote_meet_quorum_threshold (proposal, store : proposal * storage): bool =
  let votes_placed = proposal.upvotes + proposal.downvotes in
  let total_supply = frozen_total_supply(store) in
  // Note: this is equivalent to checking that the number of votes placed is
  // bigger or equal than the total supply of frozen tokens multiplied by the
  // quorum_threshold proportion.
  let reached_quorum = (votes_placed * quorum_denominator) / total_supply in
  (reached_quorum >= proposal.quorum_threshold.numerator)

// Delete a proposal from 'sProposalKeyListSortByDate'
[@inline]
let delete_proposal
    (start_date, proposal_key, store : timestamp * proposal_key * storage): storage =
  { store with proposal_key_list_sort_by_date =
    Set.remove (start_date, proposal_key) store.proposal_key_list_sort_by_date
  }

[@inline]
let fraction_to_quorum_fraction(n, d : nat * nat): unsigned_quorum_fraction
  = { numerator = (n * quorum_denominator) / d }

[@inline]
let to_signed(n : unsigned_quorum_fraction): quorum_fraction
  = { numerator = int(n.numerator) }

[@inline]
let to_unsigned(n : quorum_fraction): unsigned_quorum_fraction
  = { numerator = match is_nat(n.numerator) with
              | Some n -> n
              | None -> (failwith("BAD_UNSIGNED_CONVERSION"):nat)
    }

let update_quorum(store, config : storage * config): storage =
  let current_period = get_current_period_num(store.start_time, config.voting_period) in
  let current_cycle = period_to_cycle(current_period) in
  if store.quorum_threshold_at_cycle.last_updated_cycle = current_cycle
    then store // Quorum has been updated in this period, so no change is required.
    else
      if current_cycle > store.quorum_threshold_at_cycle.last_updated_cycle
          then
              let previous_staked = store.quorum_threshold_at_cycle.staked in
              let previous_participation = to_signed(fraction_to_quorum_fraction(previous_staked, config.governance_total_supply)) in
              let old_quorum = to_signed(store.quorum_threshold_at_cycle.quorum_threshold) in
              let quorum_change = to_signed(config.quorum_change) in
              let possible_new_quorum =
                // old_quorum + (previous_participation - old_quorum) * quorum_change
                fadd(old_quorum, fmul(quorum_change, fsub(previous_participation, old_quorum))) in
              let one_plus_max_change_percent = to_signed({ numerator = config.max_quorum_change.numerator + quorum_denominator }) in
              let min_new_quorum =
                fdiv(old_quorum, one_plus_max_change_percent) in
              let max_new_quorum =
                fmul(old_quorum, one_plus_max_change_percent) in

              let config_min_qt = to_signed(config.min_quorum_threshold) in
              let config_max_qt = to_signed(config.max_quorum_threshold) in
              let new_quorum = bound_qt(bound_qt(possible_new_quorum, min_new_quorum, max_new_quorum), config_min_qt, config_max_qt)
              in { store with quorum_threshold_at_cycle =
                   { quorum_threshold = to_unsigned(new_quorum)
                   ; last_updated_cycle = current_cycle
                   ; staked = 0n;
                   }
                 }
            else store

let propose (param, config, store : propose_params * config * storage): return =
  let store = check_is_proposal_valid (config, param, store) in
  let store = check_proposal_limit_reached (config, store) in
  let amount_to_freeze = param.frozen_token + config.fixed_proposal_fee_in_token in
  let store = update_quorum(store, config) in
  let store = stake_tk(amount_to_freeze, Tezos.sender, config.voting_period, store) in
  let store = add_proposal (param, config.voting_period, store) in
  ( ([] : operation list)
  , store
  )

[@inline]
let handle_proposal_is_over
    (config, start_date, proposal_key, store, ops, counter
      : config * timestamp * proposal_key * storage * operation list * counter
    )
    : (operation list * storage * counter) =
  let proposal = check_if_proposal_exist (proposal_key, store) in

  if is_time_reached (proposal, config.proposal_expired_time)
    then (failwith("EXPIRED_PROPOSAL") : (operation list * storage * counter))
  else (
    if is_time_reached (proposal, config.proposal_flush_time)
      && counter.current < counter.total // not finished
    then
      let counter = { counter with current = counter.current + 1n } in
      let cond =    do_total_vote_meet_quorum_threshold(proposal, store)
                && proposal.upvotes > proposal.downvotes
      in
      let store = unfreeze_proposer_and_voter_token
            (config.rejected_proposal_return_value, cond, proposal, config.voting_period, config.fixed_proposal_fee_in_token, store) in
      let (new_ops, store) =
        if cond
        then
          let (ops, new_extra) = config.decision_lambda (proposal, store.extra)
          in (ops, { store with extra = new_extra })
        else (([] : operation list), store)
      in
      let cons = fun (l, e : operation list * operation) -> e :: l in
      let ops = List.fold cons ops new_ops in
      let store = delete_proposal (start_date, proposal_key, store) in
      (ops, store, counter)
    else (ops, store, counter)
    )

// Flush all proposals that passed their voting period.
let flush(n, config, store : nat * config * storage): return =
  let store =
    if n = 0n
      then
        (failwith("BAD_ENTRYPOINT_PARAMETER") : storage)
      else store
    in

  let counter : counter =
    { current = 0n
    ; total = n
    } in
  let flush_one
      (acc, e: (operation list * storage * counter) * (timestamp * proposal_key)) =
        let (ops, store, counter) = acc in
        let (start_date, proposal_key) = e in
        handle_proposal_is_over (config, start_date, proposal_key, store, ops, counter)
      in
  let (ops, store, counter) =
    Set.fold flush_one store.proposal_key_list_sort_by_date (([] : operation list), store, counter) in
  (ops, store)

// Removes an accepted and finished proposal by key.
let drop_proposal (proposal_key, config, store : proposal_key * config * storage): return =
  let proposal = check_if_proposal_exist (proposal_key, store) in
  let proposal_is_expired = is_time_reached (proposal, config.proposal_expired_time) in

  if   (sender = proposal.proposer)
    || (sender = store.guardian && sender <> source) // Guardian cannot be equal to SOURCE
    || proposal_is_expired
  then
    let store = unfreeze_proposer_and_voter_token
          ( config.rejected_proposal_return_value
          , false // A dropped proposal is treated as rejected regardless of its actual votes
          , proposal, config.voting_period
          , config.fixed_proposal_fee_in_token, store
          ) in
    let store = delete_proposal (proposal.start_date, proposal_key, store) in
    (([] : operation list), store)
  else
    (failwith("DROP_PROPOSAL_CONDITION_NOT_MET") : return)

let freeze (amt, config, store : freeze_param * config * storage) : return =
  let addr = Tezos.sender in
  let (operation, ledger, total_supply) = freeze_on_ledger (amt, addr, store.ledger, store.total_supply, store.frozen_token_id, store.governance_token) in

  // Add the `amt` to the current period frozen token count of the freeze-history.
  let current_period = get_current_period_num(store.start_time, config.voting_period) in
  let new_freeze_history_for_address = match Big_map.find_opt addr store.freeze_history with
    | Some fh ->
        let fh = update_fh(current_period, fh) in
        add_frozen_fh(amt, fh)
    | None -> { current_period_num = current_period; staked = 0n; current_unstaked = amt; past_unstaked = 0n;}
  in
  (([operation] : operation list), { store with
      ledger = ledger
    ; total_supply = total_supply
    ; freeze_history = Big_map.update addr (Some(new_freeze_history_for_address)) store.freeze_history
  })

let unfreeze (amt, config, store : unfreeze_param * config * storage) : return =
  let addr = Tezos.sender in
  let current_period = get_current_period_num(store.start_time, config.voting_period) in

  let new_freeze_history =
    match Big_map.find_opt addr store.freeze_history with
    | Some fh ->
        let fh = update_fh(current_period, fh) in
        let fh = sub_frozen_fh(amt, fh) in
        Big_map.update addr (Some(fh)) store.freeze_history
    | None ->
        ([%Michelson ({| { FAILWITH } |} : (string * unit) -> freeze_history)]
          ("NOT_ENOUGH_FROZEN_TOKENS", ()) : freeze_history)
  in

  let (operation, ledger, total_supply) = unfreeze_on_ledger (amt, Tezos.sender, store.ledger, store.total_supply, store.frozen_token_id, store.governance_token) in

    (([operation] : operation list), { store with
        ledger = ledger
      ; total_supply = total_supply
      ; freeze_history = new_freeze_history
    })
