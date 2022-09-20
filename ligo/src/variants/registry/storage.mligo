// SPDX-FileCopyrightText: 2022 Tezos Commons
// SPDX-License-Identifier: LicenseRef-MIT-TC

#if !VARIANT_STORAGE
#define VARIANT_STORAGE

type registry_key = string
type registry_value = string
type registry = (registry_key, registry_value) big_map
type proposal_key = bytes

type contract_extra =
  { registry : registry
  ; registry_affected : (registry_key, proposal_key) big_map
  ; proposal_receivers : address set
  ; frozen_scale_value : nat
  ; frozen_extra_value : nat
  ; max_proposal_size : nat
  ; slash_scale_value : nat
  ; slash_division_value : nat
  ; min_xtz_amount : tez
  ; max_xtz_amount : tez
  }

let default_extra : contract_extra =
  { registry = (Big_map.empty : registry)
  ; registry_affected = (Big_map.empty : (registry_key, proposal_key) big_map)
  ; proposal_receivers = (Set.empty : address set)
  ; frozen_scale_value = 1n
  ; frozen_extra_value = 0n
  ; max_proposal_size = 1000n
  ; slash_scale_value = 1n
  ; slash_division_value = 1n
  ; min_xtz_amount = 0tez
  ; max_xtz_amount = 1tez
  }

#endif
