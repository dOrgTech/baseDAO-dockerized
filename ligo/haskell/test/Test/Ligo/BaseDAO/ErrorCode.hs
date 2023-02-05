-- SPDX-FileCopyrightText: 2021 Tezos Commons
-- SPDX-License-Identifier: LicenseRef-MIT-TC

module Test.Ligo.BaseDAO.ErrorCode
  ( test_ErrorCodes
  ) where

import Universum hiding (view)

import Test.HUnit ((@?=))
import Test.Tasty (TestTree, testGroup)
import Test.Tasty.HUnit (testCase)

import Ligo.BaseDAO.ErrorCodes

test_ErrorCodes :: TestTree
test_ErrorCodes = testGroup "FA2 off-chain views"
  [ testCase "Ensure the error codes are as expected" $ do
      notAdmin @?= 100
      notPendingAdmin @?= 101
      failProposalCheck @?= 102
      proposalNotExist @?= 103
      votingStageOver @?= 104
      forbiddenXtz @?= 107
      proposalNotUnique @?= 108
      missigned @?= 109
      unpackingFailed @?= 110
      unpackingProposalMetadataFailed @?= 111
      missingValue @?= 112
      notProposingStage @?= 113
      notEnoughFrozenTokens @?= 114
      badTokenContract @?= 115
      badViewContract @?= 116
      dropProposalConditionNotMet @?= 117
      expiredProposal @?= 118
      emptyFlush @?= 119
      notDelegate @?= 120
      failDecisionCallback @?= 121
      unstakeInvalidProposal @?= 123
      voterDoesNotExist @?= 124
      badState @?= 300
      -- WARNING!!! If you have to change error codes for defined errors in
      -- this file, you probably didn't follow the instructions in
      -- `./scripts/generate_error_code.hs` file.
      --
      -- If an error is no longer defined, it should be fine to remove the error
      -- from this test.
  ]
