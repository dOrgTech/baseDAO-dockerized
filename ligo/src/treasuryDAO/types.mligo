// SPDX-FileCopyrightText: 2021 TQ Tezos
// SPDX-License-Identifier: LicenseRef-MIT-TQ

#include "../types.mligo"
#include "../error_codes.mligo"


(*
 * Contract Extra
 *)
type initial_treasuryDAO_storage =
  { base_data : initial_data
  ; frozen_scale_value : nat
  ; frozen_extra_value : nat
  ; max_proposal_size : nat
  ; slash_scale_value : nat
  ; slash_division_value : nat
  ; min_xtz_amount : tez
  ; max_xtz_amount : tez
  }

type treasury_dao_transfer_proposal =
  { agora_post_id : nat
  ; transfers : transfer_type list
  }

// Treasury dao `proposal_metadata`, defining the type of its proposals.
type treasury_dao_proposal_metadata =
  | Transfer_proposal of treasury_dao_transfer_proposal
  | Update_guardian of update_guardian
  | Update_contract_delegate of update_contract_delegate

// Unpack proposal metadata (fail if the unpacked result is none).
let unpack_proposal_metadata (pm: proposal_metadata) : treasury_dao_proposal_metadata =
  match ((Bytes.unpack pm) : (treasury_dao_proposal_metadata option)) with
  | Some (v) -> v
  | None -> (failwith unpacking_proposal_metadata_failed : treasury_dao_proposal_metadata)

