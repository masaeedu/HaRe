module TypeUtilsSpec (main, spec) where

import           Test.Hspec
import           Test.QuickCheck

import           TestUtils

import qualified Data.Generics.Schemes as SYB
import qualified Data.Generics.Aliases as SYB
import qualified GHC.SYB.Utils         as SYB

import qualified Bag        as GHC
import qualified FastString as GHC
import qualified GHC        as GHC
import qualified GhcMonad   as GHC
import qualified Name       as GHC
import qualified OccName    as GHC
import qualified Outputable as GHC
import qualified RdrName    as GHC
import qualified SrcLoc     as GHC

import Control.Monad.State
import Data.Maybe
import Language.Haskell.Refact.Utils
import Language.Haskell.Refact.Utils.LocUtils
import Language.Haskell.Refact.Utils.Monad
import Language.Haskell.Refact.Utils.TypeSyn
import Language.Haskell.Refact.Utils.TypeUtils
import System.Environment

import qualified Data.Map as Map
import Data.List

main :: IO ()
main = hspec spec

spec :: Spec
spec = do

  describe "pNTtoPN" $ do
    it "Converts a PNT (located ) to a PN (unlocated)" $ do
      let pnt = PNT (GHC.L GHC.noSrcSpan (mkRdrName "aname"))
      (pNTtoPN pnt) == (PN (mkRdrName "aname")) `shouldBe` True

  -- -------------------------------------------------------------------

  describe "locToPnt" $ do
    it "returns a pnt for a given source location, if it falls anywhere in an identifier" $ do
      -- ((_, _, parsed), toks) <- parsedFileBGhc
      (t, toks) <- parsedFileBGhc
      let parsed = GHC.pm_parsed_source $ GHC.tm_parsed_module t

      let (PNT res@(GHC.L l n)) = locToPNT bFileName (7,3) parsed
      GHC.showPpr l `shouldBe` "test/testdata/B.hs:7:1-3"
      getLocatedStart res `shouldBe` (7,1)
      GHC.showRdrName n `shouldBe` "foo"

    it "returns a pnt for a given source location, if it falls anywhere in an identifier #2" $ do
      -- ((_, _, parsed), toks) <- parsedFileBGhc
      (t, toks) <- parsedFileBGhc
      let parsed = GHC.pm_parsed_source $ GHC.tm_parsed_module t
      let (PNT res@(GHC.L l n)) = locToPNT bFileName (25,8) parsed
      GHC.showRdrName n `shouldBe` "bob"
      GHC.showPpr l `shouldBe` "test/testdata/B.hs:25:7-9"
      getLocatedStart res `shouldBe` (25,7)

    it "returns the default pnt for a given source location, if it does not fall in an identifier" $ do
      -- modInfo@((_, _, mod), toks) <- parsedFileBGhc
      modInfo@(t, toks) <- parsedFileBGhc
      let mod = GHC.pm_parsed_source $ GHC.tm_parsed_module t

      let (PNT res@(GHC.L _ n)) = locToPNT bFileName (7,7) mod
      getLocatedStart res `shouldBe` (-1,-1)
      GHC.showRdrName n `shouldBe` "nothing"

    it "lists all PNTs" $ do
      -- modInfo@((_, _, mod), toks) <- parsedFileBGhc
      modInfo@(t, toks) <- parsedFileBGhc
      let mod = GHC.pm_parsed_source $ GHC.tm_parsed_module t

      let res = allPNT bFileName (7,6) mod
      show res `shouldBe`  "[(PNT test/testdata/B.hs:7:1-3 foo),(PNT test/testdata/B.hs:7:5 x),(PNT test/testdata/B.hs:7:13-15 odd),(PNT test/testdata/B.hs:7:17 x),(PNT test/testdata/B.hs:9:1-3 bob),(PNT test/testdata/B.hs:9:5 x),(PNT test/testdata/B.hs:9:7 y),(PNT test/testdata/B.hs:9:15-17 foo),(PNT test/testdata/B.hs:9:19 x),(PNT test/testdata/B.hs:9:23 x),(PNT test/testdata/B.hs:9:25 +),(PNT test/testdata/B.hs:9:37-39 foo),(PNT test/testdata/B.hs:9:41 x),(PNT test/testdata/B.hs:9:45 x),(PNT test/testdata/B.hs:9:46 +),(PNT test/testdata/B.hs:9:53 x),(PNT test/testdata/B.hs:9:55 +),(PNT test/testdata/B.hs:9:57-59 foo),(PNT test/testdata/B.hs:9:61 y),(PNT test/testdata/B.hs:11:9-11 foo),(PNT test/testdata/B.hs:11:13 x),(PNT test/testdata/B.hs:11:17 x),(PNT test/testdata/B.hs:11:19 +),(PNT test/testdata/B.hs:14:1-4 foo'),(PNT test/testdata/B.hs:14:6 x),(PNT test/testdata/B.hs:14:16-18 odd),(PNT test/testdata/B.hs:14:20 x),(PNT test/testdata/B.hs:15:3-6 True),(PNT test/testdata/B.hs:16:3-7 False),(PNT test/testdata/B.hs:18:1-4 main),(PNT test/testdata/B.hs:19:1-4 main),(PNT test/testdata/B.hs:20:3-10 putStrLn),(PNT test/testdata/B.hs:20:12 $),(PNT test/testdata/B.hs:20:14-17 show),(PNT test/testdata/B.hs:20:19 $),(PNT test/testdata/B.hs:20:22-24 foo),(PNT test/testdata/B.hs:20:29 +),(PNT test/testdata/B.hs:20:31-35 C.baz),(PNT test/testdata/B.hs:22:1-4 mary),(PNT test/testdata/B.hs:23:1-4 mary),(PNT test/testdata/B.hs:25:1 h),(PNT test/testdata/B.hs:25:3 z),(PNT test/testdata/B.hs:25:7-9 bob),(PNT test/testdata/B.hs:25:11 z),(PNT test/testdata/B.hs:27:6 D),(PNT test/testdata/B.hs:27:10 A),(PNT test/testdata/B.hs:27:14 B),(PNT test/testdata/B.hs:27:25 C),(PNT test/testdata/B.hs:29:1-7 subdecl),(PNT test/testdata/B.hs:29:9 x),(PNT test/testdata/B.hs:29:13-14 zz),(PNT test/testdata/B.hs:29:16 x),(PNT test/testdata/B.hs:31:5-6 zz),(PNT test/testdata/B.hs:31:8 n),(PNT test/testdata/B.hs:31:12 n),(PNT test/testdata/B.hs:31:14 +)]"

 
  -- -------------------------------------------------------------------

  describe "locToName" $ do
    it "returns a GHC.Name for a given source location, if it falls anywhere in an identifier" $ do
      -- ((_,renamed,_), _toks) <- parsedFileBGhc
      (t, _toks) <- parsedFileBGhc
      let renamed = fromJust $ GHC.tm_renamed_source t

      let Just (res@(GHC.L l n)) = locToName bFileName (7,3) renamed
      GHC.showPpr l `shouldBe` "test/testdata/B.hs:7:1-3"
      getLocatedStart res `shouldBe` (7,1)
      GHC.showPpr n `shouldBe` "B.foo"

    it "returns a GHC.Name for a given source location, if it falls anywhere in an identifier #2" $ do
      -- ((_, renamed,_),_toks) <- parsedFileBGhc
      (t, _toks) <- parsedFileBGhc
      let renamed = fromJust $ GHC.tm_renamed_source t

      let Just (res@(GHC.L l n)) = locToName bFileName (25,8) renamed
      GHC.showPpr n `shouldBe` "B.bob"
      GHC.showPpr l `shouldBe` "test/testdata/B.hs:25:7-9"
      getLocatedStart res `shouldBe` (25,7)

    it "returns Nothing for a given source location, if it does not fall in an identifier" $ do
      -- ((_, renamed,_),_toks) <- parsedFileBGhc
      (t, _toks) <- parsedFileBGhc
      let renamed = fromJust $ GHC.tm_renamed_source t

      let res = locToName bFileName (7,7) renamed
      res `shouldBe` Nothing

  -- -------------------------------------------------------------------

  describe "allNames" $ do 
    it "lists all Names" $ do
      -- ((_, renamed,_), _toks) <- parsedFileBGhc
      (t, _toks) <- parsedFileBGhc
      let renamed = fromJust $ GHC.tm_renamed_source t
      let res = allNames bFileName (7,6) renamed
      -- let res' = map (\(GHC.L l n) -> (GHC.showPpr $ GHC.nameUnique n,GHC.showPpr (l, n))) res
      let res' = map (\(GHC.L l n) -> (GHC.showPpr $ GHC.nameUnique n,GHC.showPpr (l, GHC.getSrcSpan n, n))) res

      -- Map.insertWith :: Ord k => (a -> a -> a) -> k -> a -> Map k a -> Map k a
      let res'' = foldl' (\m (k,a) -> Map.insertWith (++) k a m) Map.empty res'

      (sort $ Map.elems res'') `shouldBe` 
                 ["(test/testdata/B.hs:11:17, test/testdata/B.hs:11:13, x)(test/testdata/B.hs:11:13, test/testdata/B.hs:11:13, x)"
                 ,"(test/testdata/B.hs:11:9-11, test/testdata/B.hs:11:9-11, foo)"
                 ,"(test/testdata/B.hs:14:1-4, test/testdata/B.hs:14:1-4, B.foo')"
                 ,"(test/testdata/B.hs:14:20, test/testdata/B.hs:14:6, x)(test/testdata/B.hs:14:6, test/testdata/B.hs:14:6, x)"
                 ,"(test/testdata/B.hs:15:3-6, <wired into compiler>, GHC.Types.True)"
                 ,"(test/testdata/B.hs:16:3-7, <wired into compiler>, GHC.Types.False)"
                 ,"(test/testdata/B.hs:18:1-4, test/testdata/B.hs:19:1-4, B.main)(test/testdata/B.hs:19:1-4, test/testdata/B.hs:19:1-4, B.main)"
                 ,"(test/testdata/B.hs:20:14-17, <no location info>, GHC.Show.show)"
                 ,"(test/testdata/B.hs:20:19, <no location info>, GHC.Base.$)(test/testdata/B.hs:20:12, <no location info>, GHC.Base.$)"
                 ,"(test/testdata/B.hs:20:22-24, test/testdata/B.hs:7:1-3, B.foo)(test/testdata/B.hs:7:1-3, test/testdata/B.hs:7:1-3, B.foo)"
                 ,"(test/testdata/B.hs:20:29, <no location info>, GHC.Num.+)(test/testdata/B.hs:11:19, <no location info>, GHC.Num.+)(test/testdata/B.hs:9:55, <no location info>, GHC.Num.+)(test/testdata/B.hs:9:46, <no location info>, GHC.Num.+)(test/testdata/B.hs:9:25, <no location info>, GHC.Num.+)(test/testdata/B.hs:31:14, <no location info>, GHC.Num.+)"
                 ,"(test/testdata/B.hs:20:3-10,\n <no location info>,\n System.IO.putStrLn)"
                 ,"(test/testdata/B.hs:20:31-35, test/testdata/C.hs:4:1-3, C.baz)"
                 ,"(test/testdata/B.hs:22:1-4, test/testdata/B.hs:23:1-4, B.mary)(test/testdata/B.hs:23:1-4, test/testdata/B.hs:23:1-4, B.mary)"
                 ,"(test/testdata/B.hs:25:1, test/testdata/B.hs:25:1, B.h)"
                 ,"(test/testdata/B.hs:25:11, test/testdata/B.hs:25:3, z)(test/testdata/B.hs:25:3, test/testdata/B.hs:25:3, z)"
                 ,"(test/testdata/B.hs:25:7-9, test/testdata/B.hs:9:1-3, B.bob)(test/testdata/B.hs:9:1-3, test/testdata/B.hs:9:1-3, B.bob)"
                 ,"(test/testdata/B.hs:27:10, test/testdata/B.hs:27:10, B.A)"
                 ,"(test/testdata/B.hs:27:14, test/testdata/B.hs:27:14, B.B)"
                 ,"(test/testdata/B.hs:27:25, test/testdata/B.hs:27:25, B.C)"
                 ,"(test/testdata/B.hs:27:6, test/testdata/B.hs:27:6, B.D)"
                 ,"(test/testdata/B.hs:29:1-7, test/testdata/B.hs:29:1-7, B.subdecl)"
                 ,"(test/testdata/B.hs:29:16, test/testdata/B.hs:29:9, x)(test/testdata/B.hs:29:9, test/testdata/B.hs:29:9, x)"
                 ,"(test/testdata/B.hs:31:12, test/testdata/B.hs:31:8, n)(test/testdata/B.hs:31:8, test/testdata/B.hs:31:8, n)"
                 ,"(test/testdata/B.hs:31:5-6, test/testdata/B.hs:31:5-6, zz)(test/testdata/B.hs:29:13-14, test/testdata/B.hs:31:5-6, zz)"
                 ,"(test/testdata/B.hs:7:13-15, <no location info>, GHC.Real.odd)(test/testdata/B.hs:14:16-18, <no location info>, GHC.Real.odd)"
                 ,"(test/testdata/B.hs:7:17, test/testdata/B.hs:7:5, x)(test/testdata/B.hs:7:5, test/testdata/B.hs:7:5, x)"
                 ,"(test/testdata/B.hs:9:15-17, test/testdata/B.hs:9:15-17, foo)"
                 ,"(test/testdata/B.hs:9:23, test/testdata/B.hs:9:19, x)(test/testdata/B.hs:9:19, test/testdata/B.hs:9:19, x)"
                 ,"(test/testdata/B.hs:9:45, test/testdata/B.hs:9:41, x)(test/testdata/B.hs:9:41, test/testdata/B.hs:9:41, x)"
                 ,"(test/testdata/B.hs:9:53, test/testdata/B.hs:9:5, x)(test/testdata/B.hs:9:5, test/testdata/B.hs:9:5, x)"
                 ,"(test/testdata/B.hs:9:57-59, test/testdata/B.hs:9:37-39, foo)(test/testdata/B.hs:9:37-39, test/testdata/B.hs:9:37-39, foo)"
                 ,"(test/testdata/B.hs:9:61, test/testdata/B.hs:9:7, y)(test/testdata/B.hs:9:7, test/testdata/B.hs:9:7, y)"
                 ]

  -- -------------------------------------------------------------------

  describe "getName" $ do 
    it "gets a qualified Name at the top level" $ do
      -- ((_, renamed,_), _toks) <- parsedFileBGhc
      (t, _toks) <- parsedFileBGhc
      let renamed = fromJust $ GHC.tm_renamed_source t
      let Just n = getName "B.foo'" renamed
      (GHC.showPpr n) `shouldBe` "B.foo'"
      (GHC.showPpr $ GHC.getSrcSpan n) `shouldBe` "test/testdata/B.hs:14:1-4"

    it "gets any instance of an unqualified Name" $ do
      -- ((_, renamed,_), _toks) <- parsedFileBGhc
      (t, _toks) <- parsedFileBGhc
      let renamed = fromJust $ GHC.tm_renamed_source t
      let Just n = getName "foo" renamed
      (GHC.showPpr n) `shouldBe` "foo"
      (GHC.showPpr $ GHC.getSrcSpan n) `shouldBe` "test/testdata/B.hs:9:15-17"

    it "returns Nothing if the Name is not found" $ do
      -- ((_, renamed,_), _toks) <- parsedFileBGhc
      (t, _toks) <- parsedFileBGhc
      let renamed = fromJust $ GHC.tm_renamed_source t
      let res = getName "baz" renamed
      (GHC.showPpr res) `shouldBe` "Nothing"


  -- -------------------------------------------------------------------

  describe "definingDecls" $ do
    it "returns [] if not found" $ do
      -- modInfo@((_, _, mod@(GHC.L l (GHC.HsModule name exps imps ds _ _))), toks) <- parsedFileDd1Ghc
      modInfo@(t, toks) <- parsedFileDd1Ghc
      let mod@(GHC.L l (GHC.HsModule name exps imps ds _ _)) = GHC.pm_parsed_source $ GHC.tm_parsed_module t

      let res = definingDecls [(PN (mkRdrName "notdefine"))] ds True False
      GHC.showPpr res `shouldBe` "[]"

    it "finds declarations at the top level" $ do
      -- modInfo@((_, _, mod@(GHC.L l (GHC.HsModule name exps imps ds _ _))), toks) <- parsedFileDd1Ghc
      modInfo@(t, toks) <- parsedFileDd1Ghc
      let mod@(GHC.L l (GHC.HsModule name exps imps ds _ _)) = GHC.pm_parsed_source $ GHC.tm_parsed_module t

      let res = definingDecls [(PN (mkRdrName "toplevel"))] ds False False
      GHC.showPpr res `shouldBe` "[toplevel x = c * x]"

    it "includes the typedef if requested" $ do
      -- modInfo@((_, _, mod@(GHC.L l (GHC.HsModule name exps imps ds _ _))), toks) <- parsedFileDd1Ghc
      modInfo@(t, toks) <- parsedFileDd1Ghc
      let mod@(GHC.L l (GHC.HsModule name exps imps ds _ _)) = GHC.pm_parsed_source $ GHC.tm_parsed_module t

      let res = definingDecls [(PN (mkRdrName "toplevel"))] ds True False
      GHC.showPpr res `shouldBe` "[toplevel :: Integer -> Integer, toplevel x = c * x]"

    it "strips other names from typedef" $ do
      -- modInfo@((_, _, mod@(GHC.L l (GHC.HsModule name exps imps ds _ _))), toks) <- parsedFileDd1Ghc
      modInfo@(t, toks) <- parsedFileDd1Ghc
      let mod@(GHC.L l (GHC.HsModule name exps imps ds _ _)) = GHC.pm_parsed_source $ GHC.tm_parsed_module t
      let res = definingDecls [(PN (mkRdrName "c"))] ds True False
      GHC.showPpr res `shouldBe` "[c :: Integer, c = 7]"

    it "finds in a patbind" $ do
      -- modInfo@((_, _, mod@(GHC.L l (GHC.HsModule name exps imps ds _ _))), toks) <- parsedFileDd1Ghc
      modInfo@(t, toks) <- parsedFileDd1Ghc
      let mod@(GHC.L l (GHC.HsModule name exps imps ds _ _)) = GHC.pm_parsed_source $ GHC.tm_parsed_module t

      let res = definingDecls [(PN (mkRdrName "tup"))] ds False False
      GHC.showPpr res `shouldBe` "[tup@(h, t)\n   = head $ zip [1 .. 10] [3 .. ff]\n   where\n       ff = 15]"

    it "finds in a patbind, with type signature" $ do
      -- modInfo@((_, _, mod@(GHC.L l (GHC.HsModule name exps imps ds _ _))), toks) <- parsedFileDd1Ghc
      modInfo@(t, toks) <- parsedFileDd1Ghc
      let mod@(GHC.L l (GHC.HsModule name exps imps ds _ _)) = GHC.pm_parsed_source $ GHC.tm_parsed_module t

      let res = definingDecls [(PN (mkRdrName "tup"))] ds True False
      GHC.showPpr res `shouldBe` "[tup :: (Int, Int),\n tup@(h, t)\n   = head $ zip [1 .. 10] [3 .. ff]\n   where\n       ff = 15]"

    it "finds in a data decl" $ do
      -- modInfo@((_, _, mod@(GHC.L l (GHC.HsModule name exps imps ds _ _))), toks) <- parsedFileDd1Ghc
      modInfo@(t, toks) <- parsedFileDd1Ghc
      let mod@(GHC.L l (GHC.HsModule name exps imps ds _ _)) = GHC.pm_parsed_source $ GHC.tm_parsed_module t

      let res = definingDecls [(PN (GHC.mkRdrUnqual (GHC.mkDataOcc "A")))] ds True False
      GHC.showPpr res `shouldBe` "[data D = A | B String | C]"

    it "finds recursively in sub-binds" $ do
      {-
      modInfo@((_, _, mod@(GHC.L l (GHC.HsModule name exps imps ds _ _))), toks) <- parsedFileDd1Ghc
      let res = definingDecls [(PN (mkRdrName "zz"))] ds False True
      GHC.showPpr res `shouldBe` "[zz n = n + 1]" -- TODO: Currently fails, will come back to it
      -}
      pending "Currently fails, will come back to it"

    it "only finds recursively in sub-binds if asked" $ do
      -- modInfo@((_, _, mod@(GHC.L l (GHC.HsModule name exps imps ds _ _))), toks) <- parsedFileDd1Ghc
      modInfo@(t, toks) <- parsedFileDd1Ghc
      let mod@(GHC.L l (GHC.HsModule name exps imps ds _ _)) = GHC.pm_parsed_source $ GHC.tm_parsed_module t

      let res = definingDecls [(PN (mkRdrName "zz"))] ds False False
      GHC.showPpr res `shouldBe` "[]"

  -- -------------------------------------------------------------------

  describe "definingDeclsNames" $ do
    it "returns [] if not found" $ do
      -- ((_,Just renamed,_), _toks) <- parsedFileDd1Ghc
      (t, _toks) <- parsedFileDd1Ghc
      let renamed = fromJust $ GHC.tm_renamed_source t

      let Just ((GHC.L _ n)) = locToName dd1FileName (16,6) renamed
      let res = definingDeclsNames [n] (hsBinds renamed) False False
      GHC.showPpr res `shouldBe` "[]"

    it "finds declarations at the top level" $ do
      -- ((_,Just renamed,_), _toks) <- parsedFileDd1Ghc
      (t, _toks) <- parsedFileDd1Ghc
      let renamed = fromJust $ GHC.tm_renamed_source t

      let Just (GHC.L _ n) = locToName dd1FileName (3,3) renamed
      let res = definingDeclsNames [n] (hsBinds renamed) False False
      GHC.showPpr res `shouldBe` "[DupDef.Dd1.toplevel x = DupDef.Dd1.c GHC.Num.* x]"

    {-
    it "includes the typedef if requested" $ do
      ((_,renamed,_), _toks) <- parsedFileDd1Ghc
      let Just (GHC.L _ n) = locToName dd1FileName (3,3) renamed
      let res = definingDeclsNames [n] renamed True False
      GHC.showPpr res `shouldBe` "[toplevel :: Integer -> Integer,DupDef.Dd1.toplevel x = DupDef.Dd1.c GHC.Num.* x]"
    -} 

    {-
    it "strips other names from typedef" $ do
      {-
      modInfo@((_, _, mod@(GHC.L l (GHC.HsModule name exps imps ds _ _))), toks) <- parsedFileDd1Ghc
      let res = definingDecls [(PN (mkRdrName "c"))] ds True False
      GHC.showPpr res `shouldBe` "[c :: Integer, c = 7]"
      -}
      pending "Convert to definingDeclsNames"
    -}

    it "finds in a patbind" $ do
      -- ((_,Just renamed,_), _toks) <- parsedFileDd1Ghc
      (t, _toks) <- parsedFileDd1Ghc
      let renamed = fromJust $ GHC.tm_renamed_source t

      let Just (GHC.L _ n) = locToName dd1FileName (14,1) renamed
      let res = definingDeclsNames [n] (hsBinds renamed) False False
      GHC.showPpr res `shouldBe` "[DupDef.Dd1.tup@(DupDef.Dd1.h, DupDef.Dd1.t)\n   = GHC.List.head GHC.Base.$ GHC.List.zip [1 .. 10] [3 .. ff]\n   where\n       ff = 15]"


    {-
    it "finds in a patbind, with type signature" $ do
      {-
      modInfo@((_, _, mod@(GHC.L l (GHC.HsModule name exps imps ds _ _))), toks) <- parsedFileDd1Ghc
      let res = definingDecls [(PN (mkRdrName "tup"))] ds True False
      GHC.showPpr res `shouldBe` "[tup :: (Int, Int), tup@(h, t) = head $ zip [1 .. 10] [3 .. 15]]"
      -}
      pending "Convert to definingDeclsNames"
    -}

    it "finds in a data decl" $ do
      -- ((_,Just renamed,_), _toks) <- parsedFileDd1Ghc
      (t, _toks) <- parsedFileDd1Ghc
      let renamed = fromJust $ GHC.tm_renamed_source t

      let Just (GHC.L _ n) = locToName dd1FileName (16,6) renamed
      let res = definingDeclsNames [n] (hsBinds renamed) False False
      GHC.showPpr res `shouldBe` "[data D]"
      {-
      modInfo@((_, _, mod@(GHC.L l (GHC.HsModule name exps imps ds _ _))), toks) <- parsedFileDd1Ghc
      let res = definingDecls [(PN (GHC.mkRdrUnqual (GHC.mkDataOcc "A")))] ds True False
      GHC.showPpr res `shouldBe` "[data D = A | B String | C]"
      -}


    it "finds recursively in sub-binds" $ do
      {-
      modInfo@((_, _, mod@(GHC.L l (GHC.HsModule name exps imps ds _ _))), toks) <- parsedFileDd1Ghc
      let res = definingDecls [(PN (mkRdrName "zz"))] ds False True
      GHC.showPpr res `shouldBe` "[zz n = n + 1]" -- TODO: Currently fails, will come back to it
      -}
      pending "Currently fails, will come back to it"

    it "only finds recursively in sub-binds if asked" $ do
      {-
      modInfo@((_, _, mod@(GHC.L l (GHC.HsModule name exps imps ds _ _))), toks) <- parsedFileDd1Ghc
      let res = definingDecls [(PN (mkRdrName "zz"))] ds False False
      GHC.showPpr res `shouldBe` "[]"
      -}
      pending "Convert to definingDeclsNames"

  -- -------------------------------------------------------------------

  describe "isFunBindR" $ do
    it "Returns False if not a function definition" $ do
      -- modInfo@((_,Just renamed, mod@(GHC.L l (GHC.HsModule name exps imps ds _ _))), toks) <- parsedFileDd1Ghc
      modInfo@(t, toks) <- parsedFileDd1Ghc
      let mod@(GHC.L l (GHC.HsModule name exps imps ds _ _)) = GHC.pm_parsed_source $ GHC.tm_parsed_module t
      let renamed = fromJust $ GHC.tm_renamed_source t

      -- let [decl] = definingDecls [(PN (mkRdrName "tup"))] ds False False
      let Just tup = getName "DupDef.Dd1.tup" renamed
      let [decl] = definingDeclsNames [tup] (hsBinds renamed) False False
      isFunBindR decl  `shouldBe` False

    it "Returns True if a function definition" $ do
      -- modInfo@((_,Just renamed, mod@(GHC.L l (GHC.HsModule name exps imps ds _ _))), toks) <- parsedFileDd1Ghc
      modInfo@(t, toks) <- parsedFileDd1Ghc
      let mod@(GHC.L l (GHC.HsModule name exps imps ds _ _)) = GHC.pm_parsed_source $ GHC.tm_parsed_module t
      let renamed = fromJust $ GHC.tm_renamed_source t

      let Just toplevel = getName "DupDef.Dd1.toplevel" renamed
      let [decl] = definingDeclsNames [toplevel] (hsBinds renamed) False False
      isFunBindR decl  `shouldBe` True

  -- -------------------------------------------------------------------
{- ++AZ++
  describe "isSimplePatBind" $ do
    it "returns False if not a simple pat bind" $ do
      modInfo@((_, _, mod@(GHC.L l (GHC.HsModule name exps imps ds _ _))), toks) <- parsedFileDd1Ghc
      let [decl] = definingDecls [(PN (mkRdrName "toplevel"))] ds False False
      isSimplePatBind decl  `shouldBe` False

    it "returns True if a simple pat bind" $ do
      modInfo@((_, _, mod@(GHC.L l (GHC.HsModule name exps imps ds _ _))), toks) <- parsedFileDd1Ghc
      let [decl] = definingDecls [(PN (mkRdrName "tup"))] ds False False
      isSimplePatBind decl  `shouldBe` True
-}
  -- ---------------------------------------------------------------------

  describe "hsFreeAndDeclaredPNs" $ do
    it "Finds declared HsVar" $ do
      -- ((_,renamed,_), _toks) <- parsedFileDeclareGhc
      (t, _toks) <- parsedFileDeclareGhc
      let renamed = fromJust $ GHC.tm_renamed_source t

      let res = hsFreeAndDeclaredPNs renamed
          -- m = GHC.mkModule () (GHC.MkModuleName ""FreeAndDeclared.Declare")
      -- (GHC.showPpr $ map (\n -> (n, GHC.isSystemName n)) (fst res)) `shouldBe` "foo"
      -- (GHC.showPpr $ map (\n -> (n, GHC.isInternalName n)) (fst res)) `shouldBe` "foo" -- Seems to be from own source, non top-level
      -- (GHC.showPpr $ map (\n -> (n, GHC.isExternalName n)) (fst res)) `shouldBe` "foo" -- Exported somewhere?
      -- (GHC.showPpr $ map (\n -> (n, GHC.isWiredInName n)) (fst res)) `shouldBe` "foo" 
      -- (GHC.showPpr $ map (\n -> (n, GHC.nameIsLocalOrFrom m n)) (fst res)) `shouldBe` "foo" 
      (GHC.showPpr $ map (\n -> (n, GHC.nameModule_maybe n)) (fst res)) `shouldBe` "foo" 
{-
      (GHC.showPpr res)  `shouldBe` "([System.IO.getChar, GHC.Base.>>=, GHC.Base.fail,\n  System.IO.putStrLn, GHC.Base.return, a, b, y, GHC.Base.$,\n  GHC.List.head, GHC.List.zip, GHC.Num.fromInteger, GHC.Num.*,\n  FreeAndDeclared.Declare.c, x],\n"
      ++ " [FreeAndDeclared.Declare.main, a, FreeAndDeclared.Declare.unF, a,\n  b, FreeAndDeclared.Declare.unD, y, FreeAndDeclared.Declare.h,\n  FreeAndDeclared.Declare.t, FreeAndDeclared.Declare.d,\n  FreeAndDeclared.Declare.c, FreeAndDeclared.Declare.toplevel, x])"
-}

  -- ---------------------------------------------------------------------

  describe "hsFDsFromInside" $ do
    it "does something useful" $ do
      pending "Complete this"

  describe "hsFDNamesFromInside" $ do
    it "does something useful" $ do
      pending "Complete this"

  -- ---------------------------------------------------------------------

  describe "hsVisibleNames" $ do
    it "does something useful" $ do
      pending "Complete this"

  describe "hsVisiblePNs" $ do
    it "Returns [] if e does not occur in t" $ do
      -- ((_,Just renamed,_parsed),_toks) <- parsedFileDd1Ghc
      (t,_toks) <- parsedFileDd1Ghc
      let renamed = fromJust $ GHC.tm_renamed_source t

      let Just tl1  = locToExp (4,13) (4,40) renamed :: (Maybe (GHC.Located (GHC.HsExpr GHC.Name)))
      let Just tup = getName "DupDef.Dd1.tup" renamed
      let [decl] = definingDeclsNames [tup] (hsBinds renamed) False False
      (GHC.showPpr $ hsVisiblePNs tl1 tup) `shouldBe` "[]"

    it "Returns visible vars if e does occur in t" $ do
      -- ((_,Just renamed, parsed), toks) <- parsedFileDd1Ghc
      (t,_toks) <- parsedFileDd1Ghc
      let renamed = fromJust $ GHC.tm_renamed_source t

      let Just tl1  = locToExp (14,1) (14,40) renamed :: (Maybe (GHC.Located (GHC.HsExpr GHC.Name)))
      let Just tup = getName "DupDef.Dd1.tup" renamed
      let [decl] = definingDeclsNames [tup] (hsBinds renamed) False False
      (GHC.showPpr $ hsVisiblePNs tl1 tup) `shouldBe` "foo"

  -- ---------------------------------------------

  describe "inScopeInfo" $ do
    it "returns 4 element tuples for in scope names" $ do
      pending "is this still needed?"
      {-
      ((inscopes, _renamed, _parsed), _toks) <- parsedFileDd1Ghc
      let info = inScopeInfo inscopes
      (show $ head info) `shouldBe` "foo"
      -- (show $ info) `shouldBe` "foo"
      -}

  -- ---------------------------------------------

  describe "isInScopeAndUnqualified" $ do
    it "True if the identifier is in scope and unqualified" $ do
      pending "needed?"
      {-
      ((inscopes, _renamed, _parsed), _toks) <- parsedFileDd1Ghc
      let info = inScopeInfo inscopes
      (show $ head info) `shouldBe` "foo"
      -}
-- inScopeInfo for c is
-- (\"DupDef.Dd1.c\",VarName,DupDef.Dd1,Nothing)

  -- ---------------------------------------------

  describe "isInScopeAndUnqualifiedGhc" $ do
    it "True if the identifier is in scope and unqualified" $ do
      -- ((_inscopes, _renamed, _parsed), _toks) <- parsedFileDd1Ghc
      let
        comp = do
         (p,toks) <- parseSourceFileGhc "./test/testdata/DupDef/Dd1.hs"
         res1 <- isInScopeAndUnqualifiedGhc "c"
         res2 <- isInScopeAndUnqualifiedGhc "DupDef.Dd1.c"
         res3 <- isInScopeAndUnqualifiedGhc "nonexistent"
         return (res1,res2,res3)
      ((r1,r2,r3),s) <- runRefactGhcState comp
      r1 `shouldBe` True
      r2 `shouldBe` True
      r3 `shouldBe` False

  -- ---------------------------------------------

  describe "mkNewName" $ do
    it "Creates a new GHC.Name" $ do
      let
        comp = do
         name1 <- mkNewName "foo"
         name2 <- mkNewName "bar"
         return (name1,name2)
      ((n1,n2),s) <- runRefactGhcState comp
      GHC.getOccString n1 `shouldBe` "foo"
      GHC.showPpr n1 `shouldBe` "foo_H2"
      GHC.getOccString n2 `shouldBe` "bar"
      GHC.showPpr n2 `shouldBe` "bar_H3"

  -- ---------------------------------------------

  describe "duplicateDecl" $ do
    it "Duplicates a RenamedSource bind, and updates the token stream" $ do
      -- ((_,Just renamed@(g,_is,_es,_ds), parsed), toks) <- parsedFileDd1Ghc
      (t, toks) <- parsedFileDd1Ghc
      let renamed@(g,_is,_es,_ds) = fromJust $ GHC.tm_renamed_source t


      let declsr = GHC.bagToList $ getDecls renamed
      let Just (GHC.L _ n) = locToName dd1FileName (3, 1) renamed
      let
        comp = do
         newName <- mkNewName "bar"
         newName2 <- mkNewName "bar2"
         newBinding <- duplicateDecl declsr n newName2
         
         return newBinding
      let
        initialState = RefSt
           { rsSettings = RefSet ["./test/testdata/"]
           , rsUniqState = 1
           , rsModule = initRefactModule t toks
           }

      (nb,s) <- runRefactGhc comp initialState
      (GHC.showPpr n) `shouldBe` "DupDef.Dd1.toplevel"
      (GHC.showRichTokenStream $ toks) `shouldBe` "module DupDef.Dd1 where\n\n toplevel :: Integer -> Integer\n toplevel x = c * x\n\n c,d :: Integer\n c = 7\n d = 9\n\n -- Pattern bind\n tup :: (Int, Int)\n h :: Int\n t :: Int\n tup@(h,t) = head $ zip [1..10] [3..ff]\n   where\n     ff = 15\n\n data D = A | B String | C\n\n ff y = y + zz\n   where\n     zz = 1\n\n l z =\n   let\n     ll = 34\n   in ll + z\n\n dd q = do\n   let ss = 5\n   return (ss + q)\n\n "
      (GHC.showRichTokenStream $ toksFromState s) `shouldBe` "module DupDef.Dd1 where\n\n toplevel :: Integer -> Integer\n toplevel x = c * x\n\n  \n\n\n\n bar2 x = c * x\n\n c,d :: Integer\n c = 7\n d = 9\n\n -- Pattern bind\n tup :: (Int, Int)\n h :: Int\n t :: Int\n tup@(h,t) = head $ zip [1..10] [3..ff]\n   where\n     ff = 15\n\n data D = A | B String | C\n\n ff y = y + zz\n   where\n     zz = 1\n\n l z =\n   let\n     ll = 34\n   in ll + z\n\n dd q = do\n   let ss = 5\n   return (ss + q)\n\n "
      (GHC.showPpr nb) `shouldBe` "[bar2_H3 x = DupDef.Dd1.c GHC.Num.* x]"

  -- ---------------------------------------------

  describe "renamePN" $ do
    it "Replace a Name with another, updating tokens" $ do
      -- ((_,Just renamed@(_g,_is,_es,_ds), parsed), toks) <- parsedFileDd1Ghc
      -- ((_,Just renamed,_parsed), toks) <- parsedFileDd1Ghc
      (t, toks) <- parsedFileDd1Ghc
      let renamed = fromJust $ GHC.tm_renamed_source t

      let declsr = GHC.bagToList $ getDecls renamed
      let Just (GHC.L l n) = locToName dd1FileName (3, 1) renamed
      let
        comp = do
         newName <- mkNewName "bar2"
         new <- renamePN n newName True declsr
         
         return (new,newName)
      let
        initialState = RefSt
           { rsSettings = RefSet ["./test/testdata/"]
           , rsUniqState = 1
           , rsModule = initRefactModule t toks
           }

      ((nb,nn),s) <- runRefactGhc comp initialState
      (GHC.showPpr n) `shouldBe` "DupDef.Dd1.toplevel"
      (showToks $ [newNameTok l nn]) `shouldBe` "[(((3,1),(3,9)),ITvarid \"bar2\",\"bar2\")]"
      (GHC.showRichTokenStream $ toks) `shouldBe` "module DupDef.Dd1 where\n\n toplevel :: Integer -> Integer\n toplevel x = c * x\n\n c,d :: Integer\n c = 7\n d = 9\n\n -- Pattern bind\n tup :: (Int, Int)\n h :: Int\n t :: Int\n tup@(h,t) = head $ zip [1..10] [3..ff]\n   where\n     ff = 15\n\n data D = A | B String | C\n\n ff y = y + zz\n   where\n     zz = 1\n\n l z =\n   let\n     ll = 34\n   in ll + z\n\n dd q = do\n   let ss = 5\n   return (ss + q)\n\n "
      (GHC.showRichTokenStream $ toksFromState s) `shouldBe` "module DupDef.Dd1 where\n\n toplevel :: Integer -> Integer\n bar2 x = c * x\n\n c,d :: Integer\n c = 7\n d = 9\n\n -- Pattern bind\n tup :: (Int, Int)\n h :: Int\n t :: Int\n tup@(h,t) = head $ zip [1..10] [3..ff]\n   where\n     ff = 15\n\n data D = A | B String | C\n\n ff y = y + zz\n   where\n     zz = 1\n\n l z =\n   let\n     ll = 34\n   in ll + z\n\n dd q = do\n   let ss = 5\n   return (ss + q)\n\n "
      (GHC.showPpr nb) `shouldBe` "[DupDef.Dd1.dd q\n   = do { let ss = 5;\n          GHC.Base.return (ss GHC.Num.+ q) },\n DupDef.Dd1.l z = let ll = 34 in ll GHC.Num.+ z,\n DupDef.Dd1.ff y\n   = y GHC.Num.+ zz\n   where\n       zz = 1,\n DupDef.Dd1.tup@(DupDef.Dd1.h, DupDef.Dd1.t)\n   = GHC.List.head GHC.Base.$ GHC.List.zip [1 .. 10] [3 .. ff]\n   where\n       ff = 15,\n DupDef.Dd1.d = 9, DupDef.Dd1.c = 7,\n bar2_H2 x = DupDef.Dd1.c GHC.Num.* x]"


  -- ---------------------------------------------

  describe "findEntity" $ do
    it "Returns true if a syntax phrase is part of another" $ do
      let
        comp = do

         -- ((_,Just parentr,_parsed),_toks) <- parseSourceFileGhc "./test/testdata/DupDef/Dd1.hs"
         (_t, _toks) <- parseSourceFileGhc "./test/testdata/DupDef/Dd1.hs"
         parentr <- getRefactRenamed

         let mn = locToName (GHC.mkFastString "./test/testdata/DupDef/Dd1.hs") (4,1) parentr
         let (Just (ln@(GHC.L _ n))) = mn

         let declsr = GHC.bagToList $ getDecls parentr
             duplicatedDecls = definingDeclsNames [n] declsr True False

             -- res = findEntity ln duplicatedDecls
             res = findEntity' ln duplicatedDecls

         return (res,duplicatedDecls,ln)
      ((r,d,l),_s) <- runRefactGhcState comp
      (GHC.showPpr d) `shouldBe` "[DupDef.Dd1.toplevel x = DupDef.Dd1.c GHC.Num.* x]"
      -- (show l) `shouldBe` "foo"
      (show r) `shouldBe` "foo"

    it "Returns false if a syntax phrase is not part of another" $ do
      let
        comp = do

         -- ((_,Just parentr,_parsed),_toks) <- parseSourceFileGhc "./test/testdata/DupDef/Dd1.hs"
         (_t, _toks) <- parseSourceFileGhc "./test/testdata/DupDef/Dd1.hs"
         parentr <- getRefactRenamed

         let mn = locToName (GHC.mkFastString "./test/testdata/DupDef/Dd1.hs") (4,1) parentr
         let (Just (ln@(GHC.L _ n))) = mn

         let declsr = GHC.bagToList $ getDecls parentr
             duplicatedDecls = definingDeclsNames [n] declsr True False

             res = findEntity ln duplicatedDecls
             -- res = findEntity' ln duplicatedDecls

         return (res,duplicatedDecls,ln)
      ((r,d,l),_s) <- runRefactGhcState comp
      (GHC.showPpr d) `shouldBe` "[DupDef.Dd1.toplevel x = DupDef.Dd1.c GHC.Num.* x]"
      -- (show l) `shouldBe` "foo"
      (show r) `shouldBe` "foo"


  -- ---------------------------------------------

  describe "modIsExported" $ do
    it "Returns True if the module is explicitly exported" $ do
      -- ((_,_renamed,parsed), _toks) <- parsedFileDeclareGhc
      (t, _toks) <- parsedFileDeclareGhc
      let parsed = GHC.pm_parsed_source $ GHC.tm_parsed_module t

      (modIsExported parsed) `shouldBe` True

    it "Returns True if the module is exported by default" $ do
      -- ((_,_renamed,parsed), _toks) <- parsedFileDeclare1Ghc
      (t, _toks) <- parsedFileDeclare1Ghc
      let parsed = GHC.pm_parsed_source $ GHC.tm_parsed_module t

      (modIsExported parsed) `shouldBe` True

    it "Returns False if the module is explicitly not exported" $ do
      -- ((_,_renamed,parsed), _toks) <- parsedFileDeclare2Ghc
      (t, _toks) <- parsedFileDeclare2Ghc
      let parsed = GHC.pm_parsed_source $ GHC.tm_parsed_module t

      (modIsExported parsed) `shouldBe` False

  -- ---------------------------------------------

  describe "addHiding" $ do
    it "Add a hiding entry to the imports" $ do
      let
        comp = do

         -- ((_,Just renamed1,parsed1),_toks1) <- parseSourceFileGhc "./test/testdata/DupDef/Dd1.hs"
         (t1,_toks1) <- parseSourceFileGhc "./test/testdata/DupDef/Dd1.hs"
         -- ((_,Just renamed2,parsed2),_toks2) <- parseSourceFileGhc "./test/testdata/DupDef/Dd2.hs"
         (t2, _toks2) <- parseSourceFileGhc "./test/testdata/DupDef/Dd2.hs"
         let renamed1 = fromJust $ GHC.tm_renamed_source t1
         let renamed2 = fromJust $ GHC.tm_renamed_source t2

         let parsed1 = GHC.pm_parsed_source $ GHC.tm_parsed_module t1
         let parsed2 = GHC.pm_parsed_source $ GHC.tm_parsed_module t2

         let mn = locToName (GHC.mkFastString "./test/testdata/DupDef/Dd1.hs") (4,1) renamed1
         let (Just (ln@(GHC.L _ n))) = mn

         let Just (modName,_) = getModuleName parsed1
         n1 <- mkNewName "n1"
         n2 <- mkNewName "n2"
         res <- addHiding modName renamed2 [n1,n2]

         return (res)
      ((r),s) <- runRefactGhcState comp
      let toks = toksFromState s
      -- (GHC.showPpr r) `shouldBe` "foo"
      (GHC.showRichTokenStream toks) `shouldBe` "now"
      
  -- ---------------------------------------------

  describe "usedWithoutQual" $ do
    it "Returns True if the identifier is used unqualified" $ do
      -- ((_,Just renamed,parsed), toks) <- parsedFileDd1Ghc
      let
        comp = do
          (t, toks) <- parseSourceFileGhc "./test/testdata/DupDef/Dd1.hs"
          renamed <- getRefactRenamed

          let Just n@(GHC.L _ name) = locToName (GHC.mkFastString "./test/testdata/DupDef/Dd1.hs") (14,21) renamed
          res <- usedWithoutQual name renamed
          return (res,n,name)

      -- ((r,n1,n2),s) <- runRefactGhc comp $ initialState { rsTokenStream = toks }
      ((r,n1,n2),s) <- runRefactGhcState comp 

      (GHC.getOccString n2) `shouldBe` "zip"
      (GHC.showPpr n1) `shouldBe` "GHC.List.zip"
      r `shouldBe` True

    it "Returns False if the identifier is used qualified" $ do
      -- ((_,Just renamed,parsed), toks) <- parsedFileDeclareGhc
      let
        comp = do
          (t, toks) <- parseSourceFileGhc "./test/testdata/FreeAndDeclared/Declare.hs"
          renamed <- getRefactRenamed
          parsed <- getRefactParsed

          let Just n@(GHC.L _ name) = locToName (GHC.mkFastString "./test/testdata/FreeAndDeclared/Declare.hs") (36,12) renamed
          let PNT np@(GHC.L _ namep) = locToPNT (GHC.mkFastString "./test/testdata/FreeAndDeclared/Declare.hs") (36,12) parsed
          res <- usedWithoutQual name renamed
          return (res,namep,name,n)
      -- ((r,np,n1,n2),s) <- runRefactGhc comp $ initialState { rsTokenStream = toks }
      ((r,np,n1,n2),s) <- runRefactGhcState comp

      (myShow np) `shouldBe` "Qual:G:gshow"
      (myShow $ GHC.getRdrName n1) `shouldBe` "Exact:Data.Generics.Text.gshow"
      (GHC.showRdrName $ GHC.getRdrName n1) `shouldBe` "Data.Generics.Text.gshow"
      -- (GHC.showPpr $ GHC.occNameFS $ GHC.getOccName name) `shouldBe` "G.gshow"
      -- (GHC.getOccString name) `shouldBe` "G.gshow"
      (GHC.showPpr n2) `shouldBe` "Data.Generics.Text.gshow"
      r `shouldBe` False

  -- ---------------------------------------------

  describe "isExplicitlyExported" $ do
    it "Returns True if the identifier is explicitly exported" $ do
      pending "write this "

    it "Returns False if the identifier is not explicitly exported" $ do
      pending "write this "

  -- ---------------------------------------------

  describe "causeNameClashInExports" $ do
    it "Returns False if there is no clash" $ do
      pending "write this "

    it "Returns True if clash of type xx" $ do
      pending "write this "



  -- ---------------------------------------
myShow :: GHC.RdrName -> String
myShow n = case n of
  GHC.Unqual on  -> ("Unqual:" ++ (GHC.showPpr on))
  GHC.Qual ms on -> ("Qual:" ++ (GHC.showPpr ms) ++ ":" ++ (GHC.showPpr on))
  GHC.Orig ms on -> ("Orig:" ++ (GHC.showPpr ms) ++ ":" ++ (GHC.showPpr on))
  GHC.Exact en   -> ("Exact:" ++ (GHC.showPpr en))



-- ---------------------------------------------------------------------
-- Helper functions

bFileName :: GHC.FastString
bFileName = GHC.mkFastString "./test/testdata/B.hs"

parsedFileBGhc :: IO (ParseResult,[PosToken])
parsedFileBGhc = parsedFileGhc "./test/testdata/B.hs"

dd1FileName :: GHC.FastString
dd1FileName = GHC.mkFastString "./test/testdata/DupDef/Dd1.hs"

parsedFileDd1Ghc :: IO (ParseResult,[PosToken])
parsedFileDd1Ghc = parsedFileGhc "./test/testdata/DupDef/Dd1.hs"

parsedFileDeclareGhc :: IO (ParseResult,[PosToken])
parsedFileDeclareGhc = parsedFileGhc "./test/testdata/FreeAndDeclared/Declare.hs"

parsedFileDeclare1Ghc :: IO (ParseResult,[PosToken])
parsedFileDeclare1Ghc = parsedFileGhc "./test/testdata/FreeAndDeclared/Declare1.hs"

parsedFileDeclare2Ghc :: IO (ParseResult,[PosToken])
parsedFileDeclare2Ghc = parsedFileGhc "./test/testdata/FreeAndDeclared/Declare2.hs"

-- ----------------------------------------------------

-- Runners

t = withArgs ["--match", "hsFreeAndDeclaredPNs"] main
-- t = withArgs ["--match", "allNames"] main
-- t = withArgs ["--match", "definingDeclsNames"] main

-- t = withArgs ["--match", "getName"] main



