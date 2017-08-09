{-# OPTIONS_GHC -fno-warn-unused-imports #-}
{-# LANGUAGE NoImplicitPrelude           #-}
{-# LANGUAGE TemplateHaskell             #-}
{-# LANGUAGE RecordWildCards             #-}
{-# LANGUAGE OverloadedStrings           #-}

-- |
-- Module:      SwiftNav.SBP.Msg
-- Copyright:   Copyright (C) 2015 Swift Navigation, Inc.
-- License:     LGPL-3
-- Maintainer:  Mark Fine <dev@swiftnav.com>
-- Stability:   experimental
-- Portability: portable
--
-- SBP message containers.

module SwiftNav.SBP.Msg
  ( module SwiftNav.SBP.Msg
  ) where

import BasicPrelude
import Control.Lens
import Data.Aeson               hiding (decode)
import Data.Aeson.Lens
import Data.Binary
import Data.ByteString.Lazy     hiding (ByteString)
((*- for m in modules *))
import (((m)))
((*- endfor *))
import SwiftNav.SBP.Types

((* for m in msgs *))
((*- if loop.first *))
-- | An SBP message ADT composed of all defined SBP messages.
--
-- Includes SBPMsgUnknown for valid SBP messages with undefined message
-- types and SBPMsgBadCRC for SBP messages with invalid CRC checksums.
data SBPMsg =
     SBP(((m))) (((m))) Msg
((*- else *))
   | SBP(((m))) (((m))) Msg
((*- endif *))
((*- if loop.last *))
   | SBPMsgBadCrc Msg
   | SBPMsgUnknown Msg
  deriving ( Show, Read, Eq )
((*- endif *))
((*- endfor *))

$(makePrisms ''SBPMsg)

instance Binary SBPMsg where
  get = do
    preamble <- getWord8
    if preamble /= msgSBPPreamble then get else
      decoder <$> get where
        decoder m@Msg {..}
          | checkCrc m /= _msgSBPCrc = SBPMsgBadCrc m
          ((*- for m in msgs *))
          | _msgSBPType == (((m | to_global))) = SBP(((m))) (decode (fromStrict (unBytes _msgSBPPayload))) m
          ((*- endfor *))
          | otherwise = SBPMsgUnknown m

  put sm = do
    putWord8 msgSBPPreamble
    encoder sm where
      ((*- for m in msgs *))
      encoder (SBP(((m))) _ m) = put m
      ((*- endfor *))
      encoder (SBPMsgUnknown m) = put m
      encoder (SBPMsgBadCrc m) = put m

instance FromJSON SBPMsg where
  parseJSON obj@(Object o) = do
    msgType <- o .: "msg_type"
    payload <- o .: "payload"
    decoder msgType payload where
      decoder msgType payload
((*- for m in msgs *))
        | msgType == (((m | to_global))) = SBP(((m))) <$> pure (decode (fromStrict (unBytes payload))) <*> parseJSON obj
((*- endfor *))
        | otherwise = SBPMsgUnknown <$> parseJSON obj
  parseJSON _ = mzero

(<<>>) :: Value -> Value -> Value
(<<>>) a b = fromMaybe Null $ do
  a' <- preview _Object a
  b' <- preview _Object b
  pure $ review _Object $ a' <> b'

instance ToJSON SBPMsg where
((*- for m in msgs *))
  toJSON (SBP(((m))) n m) = toJSON n <<>> toJSON m
((*- endfor *))
  toJSON (SBPMsgBadCrc m) = toJSON m
  toJSON (SBPMsgUnknown m) = toJSON m

instance HasMsg SBPMsg where
((*- for m in msgs *))
  msg f (SBP(((m))) n m) = SBP(((m))) n <$> f m
((*- endfor *))
  msg f (SBPMsgUnknown m) = SBPMsgUnknown <$> f m
  msg f (SBPMsgBadCrc m) = SBPMsgBadCrc <$> f m
