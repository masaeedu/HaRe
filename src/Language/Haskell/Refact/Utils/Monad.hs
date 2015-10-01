{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE DataKinds #-}
{-# LANGUAGE DeriveFunctor #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE GeneralizedNewtypeDeriving #-}
{-# LANGUAGE RecordWildCards #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE StandaloneDeriving #-}
{-# OPTIONS_GHC -fno-warn-orphans #-}

module Language.Haskell.Refact.Utils.Monad
       (
         ParseResult
       , VerboseLevel(..)
       , RefactSettings(..)
       , RefactState(..)
       , RefactModule(..)
       , TargetModule
       , Targets
       , CabalGraph
       , RefactStashId(..)
       , RefactFlags(..)
       , StateStorage(..)

       -- The GHC Monad
       , RefactGhc(..)
       , runRefactGhc
       , getRefacSettings
       , defaultSettings
       , logSettings

       , getTargetGhcOptions
       -- , loadTarget
       , cabalModuleGraphs
       , canonicalizeGraph
       , canonicalizeModSummary

       , logm
       ) where


import qualified DynFlags      as GHC
import qualified GHC           as GHC
import qualified GHC.Paths     as GHC
import qualified GhcMonad      as GHC
import qualified HscTypes      as GHC
import qualified Outputable    as GHC

import Control.Applicative
import Control.Monad.State
--import Data.Time.Clock
import Distribution.Helper
import Exception
import qualified Language.Haskell.GhcMod             as GM
import qualified Language.Haskell.GhcMod.Internal    as GM
import qualified Language.Haskell.GhcMod.Monad.Types as GM
import Language.Haskell.Refact.Utils.Types
import Language.Haskell.GHC.ExactPrint
import Language.Haskell.GHC.ExactPrint.Utils
import System.Directory
import System.Log.Logger

import qualified Data.Map as Map
import qualified Data.Set as Set

-- Monad transformer stuff
import Control.Monad.Trans.Control ( control, liftBaseOp, liftBaseOp_)

import Debug.Trace

-- ---------------------------------------------------------------------

data VerboseLevel = Debug | Normal | Off
            deriving (Eq,Show)

data RefactSettings = RefSet
        {
        -- , rsetMainFile     :: Maybe [FilePath]
           -- TODO: re-instate rsetMainFile for when there is no cabal
           -- file.
          rsetVerboseLevel :: !VerboseLevel
        , rsetEnabledTargets :: (Bool,Bool,Bool,Bool)
        } deriving (Show)

-- deriving instance Show LineSeparator

defaultSettings :: RefactSettings
defaultSettings = RefSet
    {
    -- , rsetMainFile = Nothing
      rsetVerboseLevel = Normal
    -- , rsetEnabledTargets = (True,False,True,False)
    , rsetEnabledTargets = (True,True,True,True)
    }

logSettings :: RefactSettings
logSettings = defaultSettings { rsetVerboseLevel = Debug }

-- ---------------------------------------------------------------------

data RefactStashId = Stash !String deriving (Show,Eq,Ord)

data RefactModule = RefMod
        { rsTypecheckedMod  :: !GHC.TypecheckedModule
        , rsNameMap         :: NameMap
          -- ^ Mapping from the names in the ParsedSource to the renamed
          -- versions. Note: No strict mark, can be computed lazily.

          -- ++AZ++ TODO: Once HaRe can rename again, change rsTokenCache to something more approriate. Ditto rsStreamModified
        , rsTokenCache      :: !(TokenCache Anns)  -- ^Token stream for the current module, maybe modified, in SrcSpan tree form
        , rsStreamModified  :: !RefacResult        -- ^current module has updated the AST
        } deriving (Show)

instance Show GHC.Name where
  show n = showGhc n

deriving instance Show (GHC.Located GHC.Token)

instance Show GHC.TypecheckedModule where
  show t = showGhc (GHC.pm_parsed_source $ GHC.tm_parsed_module t)

data RefactFlags = RefFlags
       { rsDone :: !Bool -- ^Current traversal has already made a change
       } deriving (Show)

-- | State for refactoring a single file. Holds/hides the ghc-exactprint
-- annotations, which get updated transparently at key points.
data RefactState = RefSt
        { rsSettings   :: !RefactSettings -- ^Session level settings
        , rsUniqState  :: !Int -- ^ Current Unique creator value, incremented
                               -- every time it is used
        , rsSrcSpanCol :: !Int -- ^ Current SrcSpan creator value, incremented
                               -- every time it is used
        , rsFlags      :: !RefactFlags -- ^ Flags for controlling generic
                                       -- traversals
        , rsStorage    :: !StateStorage -- ^Temporary storage of values while
                                        -- refactoring takes place
        , rsCurrentTarget :: !(Maybe TargetModule) -- TODO:AZ: push this into rsModule
        , rsModule        :: !(Maybe RefactModule) -- ^The current module being refactored
        } deriving (Show)
{-
Note [rsSrcSpanCol]
~~~~~~~~~~~~~~~~~~~

The ghc-exactprint annotations are tied to a SrcSpan, and provide
deltas for the spaces between the elements in the source.

As such, the SrcSpan itself is only used as an index into the
annotation database.

When HaRe needs a new SrcSpan, for this, it generates it from this
field, to ensure uniqueness.
-}

type TargetModule = GM.ModulePath -- From ghc-mod

instance GHC.Outputable TargetModule where
  ppr t = GHC.text (show t)


-- The CabalGraph comes directly from ghc-mod
-- type CabalGraph = Map.Map ChComponentName (GM.GmComponent GMCResolved (Set.Set ModulePath))
type CabalGraph = Map.Map ChComponentName (GM.GmComponent 'GM.GMCResolved (Set.Set GM.ModulePath))

type Targets = [Either FilePath GHC.ModuleName]

-- |Result of parsing a Haskell source file. It is simply the
-- TypeCheckedModule produced by GHC.
type ParseResult = GHC.TypecheckedModule

-- |Provide some temporary storage while the refactoring is taking
-- place
data StateStorage = StorageNone
                  | StorageBind (GHC.LHsBind GHC.Name)
                  | StorageSig  (GHC.LSig GHC.Name)
                  | StorageBindRdr (GHC.LHsBind GHC.RdrName)
                  | StorageDeclRdr (GHC.LHsDecl GHC.RdrName)
                  | StorageSigRdr  (GHC.LSig GHC.RdrName)


instance Show StateStorage where
  show StorageNone         = "StorageNone"
  show (StorageBind _bind) = "(StorageBind " {- ++ (showGhc bind) -} ++ ")"
  show (StorageSig _sig)   = "(StorageSig " {- ++ (showGhc sig) -} ++ ")"
  show (StorageDeclRdr _bind) = "(StorageDeclRdr " {- ++ (showGhc bind) -} ++ ")"
  show (StorageBindRdr _bind) = "(StorageBindRdr " {- ++ (showGhc bind) -} ++ ")"
  show (StorageSigRdr _sig)   = "(StorageSigRdr " {- ++ (showGhc sig) -} ++ ")"

-- ---------------------------------------------------------------------
-- StateT and GhcT stack

newtype RefactGhc a = RefactGhc
    -- { unRefactGhc :: GM.GmlT (StateT RefactState IO) a
    { unRefactGhc :: GM.GhcModT (StateT RefactState IO) a
    } deriving ( Functor
               , Applicative
               , Alternative
               , Monad
               , MonadPlus
               , MonadIO
               , GM.GmEnv
               , GM.GmOut
               , GM.MonadIO
               , ExceptionMonad
               -- , GHC.GhcMonad
               -- , GHC.HasDynFlags
               )

-- ---------------------------------------------------------------------

runRefactGhc ::
  RefactGhc a -> Targets -> RefactState -> GM.Options -> IO (a, RefactState)
runRefactGhc comp targets initState opt = do
    -- ((merr,_log),s) <- runStateT (GM.runGhcModT opt (GM.runGmlT' targets setDynFlags (unRefactGhc comp))) initState
    ((merr,_log),s) <- runStateT (GM.runGhcModT opt (unRefactGhc comp)) initState
    case merr of
      Left err -> error (show err)
      Right a  -> return (a,s)

-- ---------------------------------------------------------------------
instance GM.GmOut (StateT RefactState IO) where

{-
instance GM.GmLog RefactGhc where
    gmlJournal v = RefactGhc (GM.gmlJournal v)
    gmlHistory   = RefactGhc GM.gmlHistory
    gmlClear     = RefactGhc GM.gmlClear
-}
instance GM.MonadIO (StateT RefactState IO) where
  liftIO = liftIO

instance MonadState RefactState RefactGhc where
    get   = RefactGhc (lift $ lift get)
    put s = RefactGhc (lift $ lift (put s))

instance GHC.GhcMonad RefactGhc where
  getSession     = RefactGhc $ GM.unGmlT GM.gmlGetSession
  setSession env = RefactGhc $ GM.unGmlT (GM.gmlSetSession env)
  -- setSession env = trace "RefactGhc.setSession" (GHC.setSession env)


-- instance GHC.GhcMonad (GM.GmT (GM.GmOutT (StateT RefactState IO))) where
--   -- getSession     = trace "other.getSession" GHC.getSession
--   -- setSession env = trace "other.setSession" (GHC.setSession env)
  -- getSession  s   = GM.gmlGetSession
--   setSession env = _ $ GM.gmlSetSession env

-- deriving instance GHC.GhcMonad (GM.GmT (GM.GmOutT (StateT RefactState IO)))

-- deriving instance GHC.HasDynFlags (GM.GmT (GM.GmOutT (StateT RefactState IO)))
-- instance GHC.HasDynFlags (GM.GmT (GM.GmOutT (StateT RefactState IO))) where
--   getDynFlags = GHC.hsc_dflags <$> GHC.getSession

instance GHC.HasDynFlags RefactGhc where
  getDynFlags = GHC.hsc_dflags <$> GHC.getSession
{-
instance GHC.HasDynFlags RefactGhc where
  getDynFlags = RefactGhc (GHC.hsc_dflags <$> GHC.getSession)


instance (MonadState RefactState (GHC.GhcT (StateT RefactState IO))) where
    get = lift get
    put = lift . put

instance (MonadTrans GHC.GhcT) where
   lift = GHC.liftGhcT

instance (Applicative m) => Alternative (GHC.GhcT m) where
  empty = empty
  (<|>) = (<|>)

instance (MonadPlus m,ExceptionMonad m) => MonadPlus (GHC.GhcT m) where
  mzero = GHC.GhcT $ \_s -> mzero
  x `mplus` y = GHC.GhcT $ \_s -> (GHC.runGhcT (Just GHC.libdir) x) `mplus` (GHC.runGhcT (Just GHC.libdir) y)
-}
-- ---------------------------------------------------------------------

instance ExceptionMonad (StateT RefactState IO) where
    gcatch act handler = control $ \run ->
        run act `gcatch` (run . handler)

    gmask = liftBaseOp gmask . liftRestore
     where liftRestore f r = f $ liftBaseOp_ r

-- ---------------------------------------------------------------------

cabalModuleGraphs :: RefactGhc [GM.GmModuleGraph]
-- cabalModuleGraphs = RefactGhc $ GM.unGmlT doCabalModuleGraphs
cabalModuleGraphs = RefactGhc doCabalModuleGraphs
-- cabalModuleGraphs = RefactGhc foo
  where
    doCabalModuleGraphs :: (GM.IOish m) => GM.GhcModT m [GM.GmModuleGraph]
    doCabalModuleGraphs = do
      mcs <- GM.cabalResolvedComponents
      let graph = map GM.gmcHomeModuleGraph $ Map.elems mcs
      return $ graph


{-
cabalModuleGraphs = RefactGhc (GM.GmlT doCabalModuleGraphs)
  where
    doCabalModuleGraphs :: (GM.IOish m) => GM.GhcModT m [GM.GmModuleGraph]
    doCabalModuleGraphs = do
      mcs <- GM.cabalResolvedComponents
      let graph = map GM.gmcHomeModuleGraph $ Map.elems mcs
      return $ graph
-}

-- ---------------------------------------------------------------------

getTargetGhcOptions :: [Either FilePath GHC.ModuleName]
                  -> RefactGhc [GM.GHCOption]
getTargetGhcOptions mfns = assert False undefined
{-
getTargetGhcOptions mfns = do
  crdl <- GM.cradle
  getOpts crdl (Set.fromList mfns)
  where
    getOpts crdl mfns'
      = RefactGhc (GM.GmlT $ GM.targetGhcOptions crdl mfns')
-}

-- ---------------------------------------------------------------------

-- |Hand the loading of targets over to ghc-mod
-- loadTarget :: [GM.GHCOption] -> [FilePath] -> RefactGhc ()
-- loadTarget opts targetFiles = RefactGhc (GM.loadTargets opts targetFiles)

-- GHC Mod version
-- loadTargets :: IOish m => [GHCOption] -> [FilePath] -> GmlT m ()

-- ---------------------------------------------------------------------

-- canonicalizeGraph ::
--   [GHC.ModSummary] -> RefactGhc [(Maybe FilePath, GHC.ModSummary)]
canonicalizeGraph graph = do
  mm' <- mapM canonicalizeModSummary graph
  return mm'

-- canonicalizeModSummary ::
--   GHC.ModSummary -> RefactGhc (Maybe FilePath, GHC.ModSummary)
canonicalizeModSummary :: (MonadIO m) =>
  GHC.ModSummary -> m (Maybe FilePath, GHC.ModSummary)
canonicalizeModSummary modSum = do
  let modSum'  = (\m -> (GHC.ml_hs_file $ GHC.ms_location m, m)) modSum
      canon ((Just fp),m) = do
        fp' <- canonicalizePath fp
        return $ (Just fp',m)
      canon (Nothing,m)  = return (Nothing,m)

  mm' <- liftIO $ canon modSum'

  return mm'

-- ---------------------------------------------------------------------

getRefacSettings :: RefactGhc RefactSettings
getRefacSettings = do
  s <- get
  return (rsSettings s)

-- ---------------------------------------------------------------------

logm :: String -> RefactGhc ()
logm string = do
  settings <- getRefacSettings
  let loggingOn = (rsetVerboseLevel settings == Debug)
             --     || (rsetVerboseLevel settings == Normal)
  when loggingOn $ do
     -- ts <- liftIO timeStamp
     -- liftIO $ warningM "HaRe" (ts ++ ":" ++ string)
     liftIO $ warningM "HaRe" (string)
  return ()

{-
timeStamp :: IO String
timeStamp = do
  k <- getCurrentTime
  return (show k)
-}

-- ---------------------------------------------------------------------

instance Show GHC.ModSummary where
  show m = show $ GHC.ms_mod m

instance Show GHC.Module where
  show m = GHC.moduleNameString $ GHC.moduleName m

-- ---------------------------------------------------------------------
