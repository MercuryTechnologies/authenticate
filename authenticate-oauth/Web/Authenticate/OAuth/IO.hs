{-# LANGUAGE DeriveDataTypeable, OverloadedStrings, StandaloneDeriving #-}
{-# LANGUAGE CPP #-}
{-# OPTIONS_GHC -Wall -fno-warn-orphans #-}
-- | This Module provides interface for the instance of 'MonadIO' instead of 'MonadIO'.
-- What this module do is just adding 'withManager' or 'runResourceT'.
module Web.Authenticate.OAuth.IO
    {-# DEPRECATED "This module is deprecated; rewrite your code using MonadResource" #-}
    (
      module Web.Authenticate.OAuth,
      getAccessToken,
      getTemporaryCredential, getTemporaryCredentialWithScope,
      getTemporaryCredentialProxy, getTemporaryCredential',
      getTokenCredential,
      getAccessTokenProxy, getTokenCredentialProxy,
      getAccessToken'
    ) where
import Network.HTTP.Client
import qualified Web.Authenticate.OAuth as OA
import Web.Authenticate.OAuth hiding
    (getAccessToken,
     getTemporaryCredential, getTemporaryCredentialWithScope,
     getTemporaryCredentialProxy, getTemporaryCredential',
     getTokenCredential, getTemporaryCredentialWithScope,
     getAccessTokenProxy, getTemporaryCredentialProxy,
     getTokenCredentialProxy,
     getAccessToken', getTemporaryCredential')
import Control.Monad.IO.Class
import qualified Data.ByteString.Char8 as BS


-- | Get temporary credential for requesting acces token.
getTemporaryCredential :: MonadIO m
                       => OA.OAuth        -- ^ OAuth Application
                       -> m OA.Credential -- ^ Temporary Credential (Request Token & Secret).
getTemporaryCredential oa = liftIO $ withManager defaultManagerSettings $ OA.getTemporaryCredential oa OA.emptyCredential

-- | Get temporary credential for requesting access token with Scope parameter.
getTemporaryCredentialWithScope :: MonadIO m
                                => BS.ByteString -- ^ Scope parameter string
                                -> OAuth         -- ^ OAuth Application
                                -> m Credential -- ^ Temporay Credential (Request Token & Secret).
getTemporaryCredentialWithScope bs oa =
  liftIO $ withManager defaultManagerSettings $ OA.getTemporaryCredentialWithScope bs oa OA.emptyCredential


-- | Get temporary credential for requesting access token via the proxy.
getTemporaryCredentialProxy :: MonadIO m
                            => Maybe Proxy   -- ^ Proxy
                            -> OAuth         -- ^ OAuth Application
                            -> m Credential -- ^ Temporary Credential (Request Token & Secret).
getTemporaryCredentialProxy p oa = liftIO $ withManager defaultManagerSettings $ OA.getTemporaryCredential' (addMaybeProxy p) oa OA.emptyCredential

getTemporaryCredential' :: MonadIO m
                        => (Request -> Request)                                 -- ^ Request Hook
                        -> OAuth                      -- ^ OAuth Application
                        -> m Credential -- ^ Temporary Credential (Request Token & Secret).
getTemporaryCredential' hook oa = liftIO $ withManager defaultManagerSettings $ OA.getTemporaryCredential' hook oa OA.emptyCredential


-- | Get Access token.
getAccessToken, getTokenCredential
               :: MonadIO m
               => OAuth         -- ^ OAuth Application
               -> Credential    -- ^ Temporary Credential with oauth_verifier
               -> m Credential -- ^ Token Credential (Access Token & Secret)
getAccessToken oa cr = liftIO $ withManager defaultManagerSettings $ OA.getAccessToken oa cr

-- | Get Access token via the proxy.
getAccessTokenProxy, getTokenCredentialProxy
               :: MonadIO m
               => Maybe Proxy   -- ^ Proxy
               -> OAuth         -- ^ OAuth Application
               -> Credential    -- ^ Temporary Credential with oauth_verifier
               -> m Credential -- ^ Token Credential (Access Token & Secret)
getAccessTokenProxy p oa cr = liftIO $ withManager defaultManagerSettings $ OA.getAccessTokenProxy p oa cr

getAccessToken' :: MonadIO m
                => (Request -> Request)                                 -- ^ Request Hook
                -> OAuth                      -- ^ OAuth Application
                -> Credential                 -- ^ Temporary Credential with oauth_verifier
                -> m Credential     -- ^ Token Credential (Access Token & Secret)
getAccessToken' hook oa cr = liftIO $ withManager defaultManagerSettings $ OA.getAccessToken' hook oa cr


getTokenCredential = getAccessToken
getTokenCredentialProxy = getAccessTokenProxy
