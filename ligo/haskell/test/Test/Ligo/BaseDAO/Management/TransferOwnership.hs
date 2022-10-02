-- SPDX-FileCopyrightText: 2021 Tezos Commons
-- SPDX-License-Identifier: LicenseRef-MIT-TC
--
{-# LANGUAGE ApplicativeDo #-}
{-# OPTIONS_GHC -Wno-incomplete-uni-patterns #-}
-- For all the incomplete list pattern matches in the calls to the
-- `withOriginated` function

module Test.Ligo.BaseDAO.Management.TransferOwnership
  ( authenticateSender
  , bypassAcceptForSelf
  , changeToPendingAdmin
  , invalidatePendingOwner
  , noPendingAdmin
  , notSetAdmin
  , pendingOwnerNotTheSame
  , rewritePendingOwner
  , transferOwnership
  , transferOwnershipSetsPendingOwner
  ) where

import Universum

import Lorentz hiding (assert, (>>))
import Morley.Util.Named
import Test.Cleveland

import Ligo.BaseDAO.ErrorCodes
import Ligo.BaseDAO.Types
import Test.Ligo.BaseDAO.Common

type WithOriginateFn m = Integer
  -> ([Address] -> Storage)
  -> ([Address] -> TAddress Parameter () -> m ())
  -> m ()

type WithStorage = Address -> Storage

transferOwnership
  :: MonadCleveland caps m
  => WithOriginateFn m -> WithStorage -> m ()
transferOwnership withOriginatedFn initialStorage =
  withOriginatedFn 2 (\(owner:_) -> initialStorage owner) $ \[_, wallet1] baseDao ->
    withSender wallet1 $ call baseDao (Call @"Transfer_ownership") (#newOwner :! wallet1)
      & expectNotAdmin

transferOwnershipSetsPendingOwner
  :: MonadCleveland caps m
  => WithOriginateFn m -> WithStorage -> m ()
transferOwnershipSetsPendingOwner withOriginatedFn initialStorage =
  withOriginatedFn 2 (\(owner:_) -> initialStorage owner) $ \[owner, wallet1] baseDao -> do
    withSender owner $ call baseDao (Call @"Transfer_ownership") (#newOwner :! wallet1)
    mNewPendingOwner <- sPendingOwnerRPC <$> getStorageRPC baseDao
    assert (mNewPendingOwner == wallet1) "Pending owner was not set as expected"

authenticateSender
  :: MonadCleveland caps m
  => WithOriginateFn m -> WithStorage -> m ()
authenticateSender withOriginatedFn initialStorage =
  withOriginatedFn 3 (\(owner:_) -> initialStorage owner) $
    \[owner, wallet1, wallet2] baseDao -> do
      withSender owner $ call baseDao (Call @"Transfer_ownership")
        (#newOwner :! wallet1)
      withSender wallet2 $ call baseDao (Call @"Accept_ownership") ()
        & expectNotPendingOwner

changeToPendingAdmin
  :: MonadCleveland caps m
  => WithOriginateFn m -> WithStorage -> m ()
changeToPendingAdmin withOriginatedFn initialStorage =
  withOriginatedFn 2 (\(owner:_) -> initialStorage owner) $
    \[owner, wallet1] baseDao -> do
      withSender owner $ call baseDao (Call @"Transfer_ownership")
        (#newOwner :! wallet1)
      withSender wallet1 $ call baseDao (Call @"Accept_ownership") ()
      administrator <- sAdminRPC <$> (getStorageRPC baseDao)
      assert (administrator == wallet1) "Administrator was not set from pending owner"

noPendingAdmin
  :: MonadCleveland caps m
  => WithOriginateFn m -> WithStorage -> m ()
noPendingAdmin withOriginatedFn initialStorage =
  withOriginatedFn 2 (\(owner:_) -> initialStorage owner) $
    \[_, wallet1] baseDao -> do
      withSender wallet1 $
        call baseDao (Call @"Accept_ownership") ()
        & expectNotPendingOwner

pendingOwnerNotTheSame
  :: MonadCleveland caps m
  => WithOriginateFn m -> WithStorage -> m ()
pendingOwnerNotTheSame withOriginatedFn initialStorage =
  withOriginatedFn 2 (\(owner:_) -> initialStorage owner) $
    \[owner, wallet1] baseDao -> withSender owner $ do
      call baseDao (Call @"Transfer_ownership")
        (#newOwner :! wallet1)
      call baseDao (Call @"Accept_ownership") ()
      & expectNotPendingOwner

notSetAdmin
  :: MonadCleveland caps m
  => WithOriginateFn m -> WithStorage -> m ()
notSetAdmin withOriginatedFn initialStorage =
  withOriginatedFn 2 (\(owner:_) -> initialStorage owner) $
    \[owner, wallet1] baseDao -> do
      withSender owner . inBatch $ do
        call baseDao (Call @"Transfer_ownership")
          (#newOwner :! wallet1)
        -- Make the call once again to make sure the admin still retains admin
        -- privileges
        call baseDao (Call @"Transfer_ownership")
          (#newOwner :! wallet1)
        pure ()

rewritePendingOwner
  :: MonadCleveland caps m
  => WithOriginateFn m -> WithStorage -> m ()
rewritePendingOwner withOriginatedFn initialStorage =
  withOriginatedFn 3 (\(owner:_) -> initialStorage owner) $
    \[owner, wallet1, wallet2] baseDao -> do
      withSender owner . inBatch $ do
        call baseDao (Call @"Transfer_ownership")
          (#newOwner :! wallet1)
        call baseDao (Call @"Transfer_ownership")
          (#newOwner :! wallet2)
        pure ()
      pendingOwner <- sPendingOwnerRPC <$> (getStorageRPC baseDao)
      assert (pendingOwner == wallet2) "Pending owner from earlier call was not re-written"

invalidatePendingOwner
  :: MonadCleveland caps m
  => WithOriginateFn m -> WithStorage -> m ()
invalidatePendingOwner withOriginatedFn initialStorage =
  withOriginatedFn 2 (\(owner:_) -> initialStorage owner) $
    \[owner, wallet1] baseDao -> do
      withSender owner . inBatch $ do
          call baseDao (Call @"Transfer_ownership")
            (#newOwner :! wallet1)
          call baseDao (Call @"Transfer_ownership")
            (#newOwner :! owner)
          pure ()
      administrator <- sAdminRPC <$> (getStorageRPC baseDao)
      assert (administrator == owner) "Pending owner from earlier call was not re-written"

bypassAcceptForSelf
  :: MonadCleveland caps m
  => WithOriginateFn m -> WithStorage -> m ()
bypassAcceptForSelf withOriginatedFn initialStorage =
  withOriginatedFn 1 (\(owner:_) -> initialStorage owner) $
    \[owner] baseDao -> do
      withSender owner $ do
        call baseDao (Call @"Transfer_ownership")
          (#newOwner :! (unTAddress baseDao))
      currentAdmin <- sAdminRPC <$> getStorage @Storage (unTAddress baseDao)
      assert (currentAdmin == (unTAddress baseDao)) "Admin address was not set"

expectNotAdmin
  :: (MonadCleveland caps m)
  => m a -> m ()
expectNotAdmin = expectFailedWith notAdmin

expectNotPendingOwner
  :: (MonadCleveland caps m)
  => m a -> m ()
expectNotPendingOwner = expectFailedWith notPendingAdmin
