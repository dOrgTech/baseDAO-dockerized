-- SPDX-FileCopyrightText: 2021 TQ Tezos
-- SPDX-License-Identifier: LicenseRef-MIT-TQ

{-# LANGUAGE RebindableSyntax #-}
{-# OPTIONS_GHC -Wno-unused-do-bind #-}

module Test.Ligo.BaseDAO.Proposal.Config
  ( IsConfigDescExt (..)
  , ConfigDesc (..)
  , (>>-)

  , ConfigConstants (..)
  , configConsts
  , ProposalFrozenTokensCheck (..)
  , RejectedProposalReturnValue (..)
  , DecisionLambdaAction (..)

  , testConfig
  , configWithRejectedProposal
  , badRejectedValueConfig
  , decisionLambdaConfig
  , voteConfig
  ) where

import Lorentz
import Universum (Constraint, (?:))

import qualified Ligo.BaseDAO.Types as DAO

-- | Configuration descriptor.
--
-- Implementing conversion of Lorentz config to Ligo config or backwards
-- would be non-trivial and take a lot of effort (though probably is doable),
-- so we can't do this for now.
-- Instead, we introduce config descriptors that compile both to Lorentz and Ligo
-- configs.
--
-- They can be useful outside of the tests, e.g. there are several commonly useful
-- implementations of 'cProposalCheck' and we can add helpers represented as instances
-- of this class.
class IsConfigDescExt config configDesc where
  -- | Fill a portion of config specified by descriptor.
  --
  -- For purposes of composing multiple descriptors we implement it as
  -- config modifier.
  fillConfig :: configDesc -> config -> config

instance IsConfigDescExt c () where
  fillConfig () c = c

-- | Require many config descriptors to have 'IsConfigDescExt' instance.
type family AreConfigDescsExt config descs :: Constraint where
  AreConfigDescsExt _ '[] = ()
  AreConfigDescsExt config (d ': ds) =
    (IsConfigDescExt config d, AreConfigDescsExt config ds)

-- | Some config descriptor.
data ConfigDesc config =
  forall configDesc. IsConfigDescExt config configDesc => ConfigDesc configDesc

instance (config ~ config1) =>
  IsConfigDescExt config (ConfigDesc config1) where
  fillConfig (ConfigDesc d) = fillConfig d

-- | Chaining capability.
data ConfigDescChain a b = ConfigDescChain a b

instance (IsConfigDescExt c a, IsConfigDescExt c b) =>
         IsConfigDescExt c (ConfigDescChain a b) where
  fillConfig (ConfigDescChain a b) = fillConfig b . fillConfig a

-- | Chains two descriptors.
-- In case they modify the same fields, the right-most takes priority.
infixr 5 >>-
(>>-) :: ConfigDesc c -> ConfigDesc c -> ConfigDesc c
ConfigDesc a >>- ConfigDesc b = ConfigDesc (ConfigDescChain a b)


-- Config descriptors
------------------------------------------------------------------------

data ConfigConstants = ConfigConstants
  { cmMaxProposals :: Maybe Natural
  , cmMaxVotes :: Maybe Natural
  , cmQuorumThreshold :: Maybe DAO.QuorumThreshold
  , cmVotingPeriod :: Maybe DAO.VotingPeriod
  }

-- | Constructor for config descriptor that overrides config constants.
--
-- Example: @configConsts{ cmMinVotingPeriod = 10 }@
configConsts :: ConfigConstants
configConsts = ConfigConstants Nothing Nothing Nothing Nothing

data ProposalFrozenTokensCheck =
  ProposalFrozenTokensCheck (Lambda ("ppFrozenToken" :! Natural) Bool)

data RejectedProposalReturnValue =
  RejectedProposalReturnValue (Lambda ("proposerFrozenToken" :! Natural) ("slash_amount" :! Natural))

proposalFrozenTokensMinBound :: Natural -> ProposalFrozenTokensCheck
proposalFrozenTokensMinBound minTokens = ProposalFrozenTokensCheck $ do
  push minTokens
  toNamed #requireValue
  if #requireValue <=. #ppFrozenToken then
    push True
  else
    push False

divideOnRejectionBy :: Natural -> RejectedProposalReturnValue
divideOnRejectionBy divisor = RejectedProposalReturnValue $ do
  fromNamed #proposerFrozenToken
  push divisor
  swap
  ediv
  ifSome car $
    push (0 :: Natural)
  toNamed #slash_amount

doNonsenseOnRejection :: RejectedProposalReturnValue
doNonsenseOnRejection = RejectedProposalReturnValue $ do
  drop; push (9999 :: Natural)
  toNamed #slash_amount

data DecisionLambdaAction =
  DecisionLambdaAction
  (["frozen_tokens" :! Natural, "proposer" :! Address] :-> '[[Operation]])

-- | Pass frozen tokens amount as argument to the given contract.
passProposerOnDecision
  :: TAddress ("proposer" :! Address) -> DecisionLambdaAction
passProposerOnDecision target = DecisionLambdaAction $ do
  drop @("frozen_tokens" :! _)
  dip @("proposer" :! _) $ do
    push target
    contract; assertSome [mt|Cannot find contract for decision lambda|]
    push zeroMutez
  transferTokens
  dip nil; cons

-- Config samples
------------------------------------------------------------------------

testConfig
  :: AreConfigDescsExt config [ConfigConstants, ProposalFrozenTokensCheck]
  => ConfigDesc config
testConfig =
  ConfigDesc (proposalFrozenTokensMinBound 10) >>-
  ConfigDesc configConsts
    { cmQuorumThreshold = Just (DAO.QuorumThreshold 1 100) }

-- | Config with longer voting period and bigger quorum threshold
-- Needed for vote related tests that do not call `flush`
voteConfig
  :: AreConfigDescsExt config [ConfigConstants, ProposalFrozenTokensCheck]
  => ConfigDesc config
voteConfig = ConfigDesc $
  ConfigDesc (proposalFrozenTokensMinBound 10) >>-
  ConfigDesc configConsts
    { cmQuorumThreshold = Just (DAO.QuorumThreshold 4 100) }

configWithRejectedProposal
  :: AreConfigDescsExt config '[RejectedProposalReturnValue]
  => ConfigDesc config
configWithRejectedProposal =
  ConfigDesc (divideOnRejectionBy 2)

badRejectedValueConfig
  :: AreConfigDescsExt config '[RejectedProposalReturnValue]
  => ConfigDesc config
badRejectedValueConfig = ConfigDesc doNonsenseOnRejection

decisionLambdaConfig
  :: AreConfigDescsExt config '[DecisionLambdaAction]
  => TAddress ("proposer" :! Address) -> ConfigDesc config
decisionLambdaConfig target = ConfigDesc $ passProposerOnDecision target

--------------------------------------------------------------------------------
--
instance IsConfigDescExt DAO.Config ConfigConstants where
  fillConfig ConfigConstants{..} DAO.Config{..} = DAO.Config
    { cMaxProposals = cmMaxProposals ?: cMaxProposals
    , cMaxVotes = cmMaxVotes ?: cMaxVotes
    , ..
    }

instance IsConfigDescExt DAO.Config DAO.QuorumThreshold where
  fillConfig qt DAO.Config{..} = DAO.Config
    { cQuorumThreshold = qt
    , ..
    }

instance IsConfigDescExt DAO.Config DAO.VotingPeriod where
  fillConfig vp DAO.Config{..} = DAO.Config
    { cVotingPeriod = vp
    , ..
    }

instance IsConfigDescExt DAO.Config ProposalFrozenTokensCheck where
  fillConfig (ProposalFrozenTokensCheck check) DAO.Config{..} = DAO.Config
    { cProposalCheck = do
        dip drop
        toFieldNamed #ppFrozenToken
        framed check
    , ..
    }

instance IsConfigDescExt DAO.Config RejectedProposalReturnValue where
  fillConfig (RejectedProposalReturnValue toReturnValue) DAO.Config{..} =
    DAO.Config
    { cRejectedProposalReturnValue = do
        dip drop
        toField #plProposerFrozenToken; toNamed #proposerFrozenToken
        framed toReturnValue
    , ..
    }

instance IsConfigDescExt DAO.Config DecisionLambdaAction where
  fillConfig (DecisionLambdaAction lam) DAO.Config{..} =
    DAO.Config
    { cDecisionLambda = do
        getField #plProposerFrozenToken; toNamed #frozen_tokens
        dip $ do toField #plProposer; toNamed #proposer
        framed lam
    , ..
    }
