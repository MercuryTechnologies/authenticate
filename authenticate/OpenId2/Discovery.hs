{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE CPP #-}

--------------------------------------------------------------------------------
-- |
-- Module      : Network.OpenID.Discovery
-- Copyright   : (c) Trevor Elliott, 2008
-- License     : BSD3
--
-- Maintainer  : Trevor Elliott <trevor@geekgateway.com>
-- Stability   :
-- Portability :
--

module OpenId2.Discovery (
    -- * Discovery
    discover
  , Discovery (..)
  ) where

-- Friends
import OpenId2.Types
import OpenId2.XRDS

-- Libraries
import Data.Char
import Data.Maybe
import Network.HTTP.Conduit
import qualified Data.ByteString.Char8 as S8
import Control.Arrow (first)
import Control.Monad.IO.Class (MonadIO (liftIO))
import Control.Monad (mplus, liftM, guard)
import qualified Data.CaseInsensitive as CI
import Data.Text (Text, unpack)
import Data.Text.Lazy (toStrict)
import qualified Data.Text as T
import Data.Text.Lazy.Encoding (decodeUtf8With)
import Data.Text.Encoding.Error (lenientDecode)
import Control.Applicative ((<$>), (<*>))
import Network.HTTP.Types (status200)
import Control.Exception (throwIO)
import Text.HTML.DOM
import Text.XML.Cursor
import Text.XML (Node (..), Element (..))
import qualified Data.Map as Map

data Discovery = Discovery1 Text (Maybe Text)
               | Discovery2 Provider Identifier IdentType
    deriving Show

-- | Attempt to resolve an OpenID endpoint, and user identifier.
discover :: MonadIO m => Identifier -> Manager -> m Discovery
discover ident@(Identifier i) manager = do
    res1 <- discoverYADIS ident Nothing 10 manager
    case res1 of
        Just (x, y, z) -> return $ Discovery2 x y z
        Nothing -> do
            res2 <- discoverHTML ident manager
            case res2 of
                Just x -> return x
                Nothing -> liftIO $ throwIO $ DiscoveryException $ unpack i

-- YADIS-Based Discovery -------------------------------------------------------

-- | Attempt a YADIS based discovery, given a valid identifier.  The result is
--   an OpenID endpoint, and the actual identifier for the user.
discoverYADIS :: MonadIO m
              => Identifier
              -> Maybe String
              -> Int -- ^ remaining redirects
              -> Manager
              -> m (Maybe (Provider, Identifier, IdentType))
discoverYADIS _ _ 0 _ =
#if MIN_VERSION_http_conduit(2, 2, 0)
    error "discoverYADIS: Too many redirects"
#else
    liftIO $ throwIO $ TooManyRedirects
#if MIN_VERSION_http_conduit(1,6,0)
        []
#endif
#endif
discoverYADIS ident mb_loc redirects manager = do
    let uri = fromMaybe (unpack $ identifier ident) mb_loc
#if MIN_VERSION_http_conduit(2, 2, 0)
    req <- liftIO $ parseRequest uri
#else
    req <- liftIO $ parseUrl uri
#endif
    res <- httpLbs req
#if !MIN_VERSION_http_conduit(2, 2, 0)
#if MIN_VERSION_http_conduit(1, 9, 0)
        { checkStatus = \_ _ _ -> Nothing
#else
        { checkStatus = \_ _ -> Nothing
#endif
        }
#endif
        manager
    let mloc = fmap S8.unpack
             $ lookup "x-xrds-location"
             $ map (first $ map toLower . S8.unpack . CI.original)
             $ responseHeaders res
    let mloc' = if mloc == mb_loc then Nothing else mloc
    if responseStatus res == status200
        then
          case mloc' of
            Just loc -> discoverYADIS ident (Just loc) (redirects - 1) manager
            Nothing  -> do
              let mdoc = parseXRDS $ responseBody res
              case mdoc of
                  Just doc -> return $ parseYADIS ident doc
                  Nothing -> return Nothing
        else return Nothing


-- | Parse out an OpenID endpoint, and actual identifier from a YADIS xml
-- document.
parseYADIS :: Identifier -> XRDS -> Maybe (Provider, Identifier, IdentType)
parseYADIS ident = listToMaybe . mapMaybe isOpenId . concat
  where
  isOpenId svc = do
    let tys = serviceTypes svc
        localId = maybe ident Identifier $ listToMaybe $ serviceLocalIDs svc
        f (x,y) | x `elem` tys = Just y
                | otherwise    = Nothing
    (lid, itype) <- listToMaybe $ mapMaybe f
      [ ("http://specs.openid.net/auth/2.0/server", (ident, OPIdent))
      -- claimed identifiers
      , ("http://specs.openid.net/auth/2.0/signon", (localId, ClaimedIdent))
      , ("http://openid.net/signon/1.0"           , (localId, ClaimedIdent))
      , ("http://openid.net/signon/1.1"           , (localId, ClaimedIdent))
      ]
    uri <- listToMaybe $ serviceURIs svc
    return (Provider uri, lid, itype)


-- HTML-Based Discovery --------------------------------------------------------

-- | Attempt to discover an OpenID endpoint, from an HTML document.  The result
-- will be an endpoint on success, and the actual identifier of the user.
discoverHTML :: MonadIO m => Identifier -> Manager -> m (Maybe Discovery)
discoverHTML ident'@(Identifier ident) manager = do
    req <- liftIO $ parseUrlThrow $ unpack ident
    lbs <- liftM responseBody $ httpLbs req manager
    return $ parseHTML ident' . toStrict . decodeUtf8With lenientDecode $ lbs

-- | Parse out an OpenID endpoint and an actual identifier from an HTML
-- document.
parseHTML :: Identifier -> Text -> Maybe Discovery
parseHTML ident text0 = do
    let doc = parseSTChunks [text0]
        cursor = fromDocument doc
        links = map node $ cursor $// element "link"
        ls = do
          NodeElement (Element "link" as _) <- links
          Just rel <- pure $ Map.lookup "rel" as
          Just href <- pure $ Map.lookup "href" as
          guard $ "openid" `T.isPrefixOf` rel
          pure (rel, href)
    resolve ls
  where
    resolve1 ls = do
      server <- lookup "openid.server" ls
      let delegate = lookup "openid.delegate" ls
      return $ Discovery1 server delegate
    resolve2 ls = do
      prov <- lookup "openid2.provider" ls
      let lid = maybe ident Identifier $ lookup "openid2.local_id" ls
      -- Based on OpenID 2.0 spec, section 7.3.3, HTML discovery can only
      -- result in a claimed identifier.
      return $ Discovery2 (Provider prov) lid ClaimedIdent

    resolve ls = resolve2 ls `mplus` resolve1 ls
