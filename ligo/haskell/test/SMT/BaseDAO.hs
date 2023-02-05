-- SPDX-FileCopyrightText: 2021 Tezos Commons
-- SPDX-License-Identifier: LicenseRef-MIT-TC

{-# LANGUAGE RebindableSyntax #-}

module SMT.BaseDAO
  ( hprop_SMT
  ) where

import Universum hiding (drop, swap)

import Hedgehog
import Lorentz hiding (div, fromInteger, now, (>>))

import Hedgehog.Gen qualified as Gen
import Hedgehog.Range qualified as Range

import Ligo.BaseDAO.Types
import SMT.Common.Run
import SMT.Common.Types
import Test.Ligo.BaseDAO.Common (ContractType(..), makeProposalKey, metadataSize)

hprop_SMT :: Property
hprop_SMT =
  let
    option = SmtOption
      { soMkPropose = genPropose
      , soMkCustomCalls = pure []
      , soModifyS = addBaseDaoConfig
      , soContractType = BaseDaoContract

      , soProposalCheck = \_ -> pass

      , soRejectedProposalSlashValue = \_ -> do
        pure 1

      , soDecisionCallback = \DecisionCallbackInput'{..} -> do
        pure $ ([], diExtra, Nothing)

      , soCustomEps = \_ -> pure ()
      }
  in
    withTests 30 $ property $ do
      runBaseDaoSMT @'Base option

addBaseDaoConfig :: StorageSkeleton (VariantToExtra 'Base) -> StorageSkeleton (VariantToExtra 'Base)
addBaseDaoConfig fs = fs { sExtra = () }

genPropose :: MkGenPropose 'Base
genPropose senderInput delegate1 invalidFrom = do
  from <- Gen.element [senderInput, invalidFrom, delegate1]
  metadata <- Gen.integral (Range.constant 1 100)
  let proposalMeta = lPackValueRaw @Natural metadata
  let
      metaSize = metadataSize proposalMeta
      param = ProposeParams
          { ppFrom = from
          , ppFrozenToken = metaSize
          , ppProposalMetadata = proposalMeta
          }
      proposalKey = makeProposalKey param

  pure $ (\_ _ -> (XtzAllowed $ ConcreteEp $ Propose param, metaSize, proposalKey))
