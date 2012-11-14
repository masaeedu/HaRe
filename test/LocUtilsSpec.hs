module LocUtilsSpec (main, spec) where

import           Test.Hspec
import           Test.QuickCheck

import           TestUtils

import qualified Bag        as GHC
import qualified Digraph    as GHC
import qualified FastString as GHC
import qualified GHC        as GHC
import qualified GhcMonad   as GHC
import qualified Lexer      as GHC
import qualified Name       as GHC
import qualified Outputable as GHC
import qualified RdrName    as GHC
import qualified SrcLoc     as GHC

import Control.Monad.State
import Data.Maybe
import Language.Haskell.Refact.Utils
import Language.Haskell.Refact.Utils.Monad
import Language.Haskell.Refact.Utils.LocUtils
import Language.Haskell.Refact.Utils.TypeSyn
import Language.Haskell.Refact.Utils.TypeUtils

-- ---------------------------------------------------------------------

main :: IO ()
main = hspec spec

spec :: Spec
spec = do

  describe "startEndLocIncComments" $ do
    it "get start&end loc, including leading and trailing comments" $ do
      -- ((_,Just renamed,_), toks) <- parsedFileDeclareGhc
      (t, toks) <- parsedFileDeclareGhc
      let renamed = fromJust $ GHC.tm_renamed_source t

      let declsr = getDecls renamed

      let decls = filter isFunOrPatBindR declsr

      let decl = head $ drop 4 decls
      let (startPos,endPos) = startEndLocIncComments toks decl

      -- (GHC.showPpr decls) `shouldBe` "unD (B y) = y"

      (GHC.showPpr decl) `shouldBe` "FreeAndDeclared.Declare.unD (FreeAndDeclared.Declare.B y) = y"

      (show $ getStartEndLoc decl) `shouldBe` "((21,1),(21,14))"

      (show (startPos,endPos)) `shouldBe` "((20,1),(22,1))"

  -- -------------------------------------------------------------------

  describe "tokenise" $ do
    it "converts a string to Haskell tokens" $ do
      let startLoc = (GHC.mkRealSrcLoc (GHC.mkFastString "foo") 3 4)
      toks <- tokenise startLoc 0 False "x y\n  z"
      (showToks toks) `shouldBe` ("[(((3,4),(3,5)),ITvarid \"x\",\"x\")," ++
                                   "(((3,6),(3,7)),ITvarid \"y\",\"y\")," ++
                                   "(((4,3),(4,4)),ITvarid \"z\",\"z\")]")

    it "indents the string of tokens if required" $ do
      let startLoc = (GHC.mkRealSrcLoc (GHC.mkFastString "foo") 3 4)
      toks <- tokenise startLoc 5 True "x y\n  z"
      (showToks toks) `shouldBe` ("[(((3,9),(3,10)),ITvarid \"x\",\"x\")," ++
                                   "(((3,11),(3,12)),ITvarid \"y\",\"y\")," ++
                                   "(((4,8),(4,9)),ITvarid \"z\",\"z\")]")

  -- -------------------------------------------------------------------

  describe "lexStringToRichTokens" $ do
    it "parses a string to Haskell tokens" $ do
      let startLoc = (GHC.mkRealSrcLoc (GHC.mkFastString "foo") 3 4)
      toks <- lexStringToRichTokens startLoc "toplevel x y z"
      (showToks toks) `shouldBe` ("[(((3,4),(3,12)),ITvarid \"toplevel\",\"toplevel\")," ++ 
                                   "(((3,13),(3,14)),ITvarid \"x\",\"x\")," ++ 
                                   "(((3,15),(3,16)),ITvarid \"y\",\"y\")," ++ 
                                   "(((3,17),(3,18)),ITvarid \"z\",\"z\")]")

  -- -------------------------------------------------------------------

  describe "updateToks" $ do
    it "needs a test or two" $ do
      pending "write this test"

  -- -------------------------------------------------------------------

  describe "splitToks" $ do
    it "Split the tokens into a front, middle and end" $ do
      (t,toks) <- parsedFileCaseBGhc
      let renamed = fromJust $ GHC.tm_renamed_source t

      let Just expr = locToExp (4,7) (4,43) renamed :: Maybe (GHC.Located (GHC.HsExpr GHC.Name))
          (_front,middle,_back) = splitToks ((4,9),(4,36)) toks
      (showToks middle) `shouldBe`
               "[(((4,9),(4,11)),ITif,\"if\")," ++
               "(((4,12),(4,13)),IToparen,\"(\")," ++
               "(((4,13),(4,16)),ITvarid \"odd\",\"odd\")," ++
               "(((4,17),(4,18)),ITvarid \"x\",\"x\")," ++
               "(((4,18),(4,19)),ITcparen,\")\")," ++
               "(((4,20),(4,24)),ITthen,\"then\")," ++
               "(((4,25),(4,30)),ITstring \"Odd\",\"\\\"Odd\\\"\")," ++
               "(((4,31),(4,35)),ITelse,\"else\")," ++
               "(((4,36),(4,42)),ITstring \"Even\",\"\\\"Even\\\"\")]"
      (GHC.showRichTokenStream middle) `shouldBe` "\n\n\n         if (odd x) then \"Odd\" else \"Even\""

  -- -------------------------------------------------------------------

  describe "replaceToks" $ do
    it "Replaces a set of tokens in a token stream" $ do
      (t,toks) <- parsedFileCaseBGhc
      let renamed = fromJust $ GHC.tm_renamed_source t

      let Just expr = locToExp (4,7) (4,43) renamed :: Maybe (GHC.Located (GHC.HsExpr GHC.Name))
          (front,middle,_back) = splitToks ((4,9),(4,36)) toks
      (showToks middle) `shouldBe`
               "[(((4,9),(4,11)),ITif,\"if\")," ++
               "(((4,12),(4,13)),IToparen,\"(\")," ++
               "(((4,13),(4,16)),ITvarid \"odd\",\"odd\")," ++
               "(((4,17),(4,18)),ITvarid \"x\",\"x\")," ++
               "(((4,18),(4,19)),ITcparen,\")\")," ++
               "(((4,20),(4,24)),ITthen,\"then\")," ++
               "(((4,25),(4,30)),ITstring \"Odd\",\"\\\"Odd\\\"\")," ++
               "(((4,31),(4,35)),ITelse,\"else\")," ++
               "(((4,36),(4,42)),ITstring \"Even\",\"\\\"Even\\\"\")]"
      (GHC.showRichTokenStream middle) `shouldBe` "\n\n\n         if (odd x) then \"Odd\" else \"Even\""
      (showToks [(head front)]) `shouldBe` "[(((1,1),(1,7)),ITmodule,\"module\")]"

      let newToks = replaceToks middle (4,17) (4,17) [(head front)]
      (showToks newToks) `shouldBe`
               "[(((4,9),(4,11)),ITif,\"if\")," ++
               "(((4,12),(4,13)),IToparen,\"(\")," ++
               "(((4,13),(4,16)),ITvarid \"odd\",\"odd\")," ++
               -- "(((4,17),(4,18)),ITvarid \"x\",\"x\")," ++
               "(((1,1),(1,7)),ITmodule,\"module\")," ++
               "(((4,18),(4,19)),ITcparen,\")\")," ++
               "(((4,20),(4,24)),ITthen,\"then\")," ++
               "(((4,25),(4,30)),ITstring \"Odd\",\"\\\"Odd\\\"\")," ++
               "(((4,31),(4,35)),ITelse,\"else\")," ++
               "(((4,36),(4,42)),ITstring \"Even\",\"\\\"Even\\\"\")]"


  -- -------------------------------------------------------------------

  describe "deleteToks" $ do
    it "Deletes a set of tokens from a token stream" $ do
      (t,toks) <- parsedFileCaseBGhc
      let toks' = take 25 toks
      (showToks toks') `shouldBe` 
               "[(((1,1),(1,7)),ITmodule,\"module\")," ++ 
                "(((1,8),(1,9)),ITconid \"B\",\"B\")," ++
                "(((1,10),(1,15)),ITwhere,\"where\")," ++ 
                "(((2,1),(2,35)),ITlineComment \"-- Test for refactor of if to case\",\"-- Test for refactor of if to case\")," ++
                "(((4,1),(4,1)),ITvocurly,\"\")," ++
                "(((4,1),(4,4)),ITvarid \"foo\",\"foo\")," ++
                "(((4,5),(4,6)),ITvarid \"x\",\"x\")," ++
                "(((4,7),(4,8)),ITequal,\"=\")," ++ 
                "(((4,9),(4,11)),ITif,\"if\")," ++
                "(((4,12),(4,13)),IToparen,\"(\")," ++
                "(((4,13),(4,16)),ITvarid \"odd\",\"odd\")," ++
                "(((4,17),(4,18)),ITvarid \"x\",\"x\")," ++
                "(((4,18),(4,19)),ITcparen,\")\")," ++
                "(((4,20),(4,24)),ITthen,\"then\")," ++
                "(((4,25),(4,30)),ITstring \"Odd\",\"\\\"Odd\\\"\")," ++
                "(((4,31),(4,35)),ITelse,\"else\")," ++
                "(((4,36),(4,42)),ITstring \"Even\",\"\\\"Even\\\"\")," ++
                "(((6,1),(6,1)),ITsemi,\"\")," ++
                "(((6,1),(6,4)),ITvarid \"bob\",\"bob\")," ++
                "(((6,5),(6,6)),ITvarid \"x\",\"x\")," ++
                "(((6,7),(6,8)),ITvarid \"y\",\"y\")," ++
                "(((6,9),(6,10)),ITequal,\"=\")," ++
                "(((6,11),(6,12)),ITvarid \"x\",\"x\")," ++
                "(((6,13),(6,14)),ITvarsym \"+\",\"+\")," ++
                "(((6,15),(6,16)),ITvarid \"y\",\"y\")]"
      (GHC.showRichTokenStream toks') `shouldBe` "module B where\n -- Test for refactor of if to case\n\n foo x = if (odd x) then \"Odd\" else \"Even\"\n\n bob x y = x + y"

      let newToks = deleteToks toks' (4,9) (4,42)
      (showToks newToks) `shouldBe`
               "[(((1,1),(1,7)),ITmodule,\"module\")," ++ 
                "(((1,8),(1,9)),ITconid \"B\",\"B\")," ++
                "(((1,10),(1,15)),ITwhere,\"where\")," ++ 
                "(((2,1),(2,35)),ITlineComment \"-- Test for refactor of if to case\",\"-- Test for refactor of if to case\")," ++
                "(((4,1),(4,1)),ITvocurly,\"\")," ++
                "(((4,1),(4,4)),ITvarid \"foo\",\"foo\")," ++
                "(((4,5),(4,6)),ITvarid \"x\",\"x\")," ++
                "(((4,7),(4,8)),ITequal,\"=\")," ++ 
                -- "(((4,9),(4,11)),ITif,\"if\")," ++
                -- "(((4,12),(4,13)),IToparen,\"(\")," ++
                -- "(((4,13),(4,16)),ITvarid \"odd\",\"odd\")," ++
                -- "(((4,17),(4,18)),ITvarid \"x\",\"x\")," ++
                -- "(((4,18),(4,19)),ITcparen,\")\")," ++
                -- "(((4,20),(4,24)),ITthen,\"then\")," ++
                -- "(((4,25),(4,30)),ITstring \"Odd\",\"\\\"Odd\\\"\")," ++
                -- "(((4,31),(4,35)),ITelse,\"else\")," ++
                -- "(((4,36),(4,42)),ITstring \"Even\",\"\\\"Even\\\"\")," ++
                -- "(((6,1),(6,1)),ITsemi,\"\")," ++
                "(((6,1),(6,4)),ITvarid \"bob\",\"bob\")," ++
                "(((6,5),(6,6)),ITvarid \"x\",\"x\")," ++
                "(((6,7),(6,8)),ITvarid \"y\",\"y\")," ++
                "(((6,9),(6,10)),ITequal,\"=\")," ++
                "(((6,11),(6,12)),ITvarid \"x\",\"x\")," ++
                "(((6,13),(6,14)),ITvarsym \"+\",\"+\")," ++
                "(((6,15),(6,16)),ITvarid \"y\",\"y\")]"


  -- -------------------------------------------------------------------

  describe "getSrcSpan" $ do
    it "Finds the top SrcSpan" $ do
      (t, toks) <- parsedFileDd1Ghc
      let renamed = fromJust $ GHC.tm_renamed_source t
      let declsr = getDecls renamed
          ss = getSrcSpan declsr
      (GHC.showPpr declsr) `shouldBe` "[DupDef.Dd1.dd q\n   = do { let ss = 5;\n          GHC.Base.return (ss GHC.Num.+ q) },\n DupDef.Dd1.l z = let ll = 34 in ll GHC.Num.+ z,\n DupDef.Dd1.ff y\n   = y GHC.Num.+ zz\n   where\n       zz = 1,\n DupDef.Dd1.tup@(DupDef.Dd1.h, DupDef.Dd1.t)\n   = GHC.List.head GHC.Base.$ GHC.List.zip [1 .. 10] [3 .. ff]\n   where\n       ff :: GHC.Types.Int\n       ff = 15,\n DupDef.Dd1.d = 9, DupDef.Dd1.c = 7,\n DupDef.Dd1.toplevel x = DupDef.Dd1.c GHC.Num.* x]"
      (GHC.showPpr ss) `shouldBe` "Just test/testdata/DupDef/Dd1.hs:(30,1)-(32,17)"

  -- -------------------------------------------------------------------

  describe "getToks" $ do
    it "get a token stream from the middle of tokens" $ do
      (_t,toks) <- parsedFileCaseBGhc
      let
          middle = getToks ((4,9),(4,36)) toks
      (showToks middle) `shouldBe`
               "[(((4,9),(4,11)),ITif,\"if\")," ++
               "(((4,12),(4,13)),IToparen,\"(\")," ++
               "(((4,13),(4,16)),ITvarid \"odd\",\"odd\")," ++
               "(((4,17),(4,18)),ITvarid \"x\",\"x\")," ++
               "(((4,18),(4,19)),ITcparen,\")\")," ++
               "(((4,20),(4,24)),ITthen,\"then\")," ++
               "(((4,25),(4,30)),ITstring \"Odd\",\"\\\"Odd\\\"\")," ++
               "(((4,31),(4,35)),ITelse,\"else\")," ++
               "(((4,36),(4,42)),ITstring \"Even\",\"\\\"Even\\\"\")]"
      (GHC.showRichTokenStream middle) `shouldBe` "\n\n\n         if (odd x) then \"Odd\" else \"Even\""

  -- -------------------------------------------------------------------

  describe "addFormalParams" $ do
    it "adds new parameters to a token stream??" $ do
      let
        comp = do

         (t, toks) <- parseSourceFileGhc "./test/testdata/DupDef/Dd1.hs"
         putParsedModule t toks
         parentr <- getRefactRenamed

         let mn = locToName (GHC.mkFastString "./test/testdata/DupDef/Dd1.hs") (4,1) parentr
         let (Just (ln@(GHC.L _ n))) = mn

         n1   <- mkNewName "n1"
         n2   <- mkNewName "n2"

         let declsr = getDecls parentr
             tlDecls = definingDeclsNames [n] declsr True False
             pats = [GHC.noLoc (GHC.VarPat n1), GHC.noLoc (GHC.VarPat n2)]

         addFormalParams tlDecls pats

         return (tlDecls,ln)
      ((d,l),s) <- runRefactGhcState comp
      (GHC.showPpr l) `shouldBe` "DupDef.Dd1.toplevel";
      (GHC.showPpr d) `shouldBe` "[DupDef.Dd1.toplevel x = DupDef.Dd1.c GHC.Num.* x]"
      -- (showToks $ take 20 $ toksFromState s) `shouldBe` ""
      (GHC.showRichTokenStream $ toksFromState s) `shouldBe` "module DupDef.Dd1 where\n\n  toplevel :: Integer -> Integer\n  toplevel x = c * x n1 n2\n\n  c , d :: Integer\n  c = 7\n  d = 9\n\n -- Pattern bind\n  tup :: ( Int , Int )\n  h :: Int\n  t :: Int\n  tup @ ( h , t ) = head $ zip [ 1 .. 10 ] [ 3 .. ff ]\n   where\n      ff :: Int\n      ff = 15\n\n   data D = A | B String | C\n\n  ff y = y + zz\n   where\n      zz = 1\n\n   l z =\n   let\n      ll = 34\n    in ll + z\n\n  dd q = do\n    let  ss = 5\n     return ( ss + q )\n\n  "



  -- -------------------------------------------------------------------

  describe "reAlignToks" $ do
    it "spaces tokens out if they overlap" $ do
      let toks = [mkToken GHC.ITsemi (1,1) "v1"
                 ,mkToken GHC.ITsemi (1,1) "v2"
                 ,mkToken GHC.ITsemi (1,1) "v3"
                 ]
      (showToks toks) `shouldBe` "[(((1,1),(1,3)),ITsemi,\"v1\"),(((1,1),(1,3)),ITsemi,\"v2\"),(((1,1),(1,3)),ITsemi,\"v3\")]"
      (showToks $ reAlignToks toks) `shouldBe` "[(((1,1),(1,3)),ITsemi,\"v1\"),(((1,4),(1,6)),ITsemi,\"v2\"),(((1,7),(1,9)),ITsemi,\"v3\")]"

  -- -------------------------------------------------------------------

  describe "newLnToken" $ do
    it "Bumps to next line" $ do
      (_t,toks) <- parsedFileCaseBGhc
      let
          middle = getToks ((4,9),(4,36)) toks
      (showToks middle) `shouldBe`
               "[(((4,9),(4,11)),ITif,\"if\")," ++
               "(((4,12),(4,13)),IToparen,\"(\")," ++
               "(((4,13),(4,16)),ITvarid \"odd\",\"odd\")," ++
               "(((4,17),(4,18)),ITvarid \"x\",\"x\")," ++
               "(((4,18),(4,19)),ITcparen,\")\")," ++
               "(((4,20),(4,24)),ITthen,\"then\")," ++
               "(((4,25),(4,30)),ITstring \"Odd\",\"\\\"Odd\\\"\")," ++
               "(((4,31),(4,35)),ITelse,\"else\")," ++
               "(((4,36),(4,42)),ITstring \"Even\",\"\\\"Even\\\"\")]"
      (showToks [newLnToken (head middle)]) `shouldBe` "[(((5,1),(5,1)),ITvocurly,\"\")]"


  -- -------------------------------------------------------------------

  describe "foo" $ do
    it "needs a test or two" $ do
      pending "write this test"

-- ---------------------------------------------------------------------
-- Helper functions

bFileName :: GHC.FastString
bFileName = GHC.mkFastString "./test/testdata/B.hs"

parsedFileBGhc :: IO (ParseResult,[PosToken])
parsedFileBGhc = parsedFileGhc "./test/testdata/B.hs"

caseBFileName :: GHC.FastString
caseBFileName = GHC.mkFastString "./test/testdata/Case/B.hs"

parsedFileCaseBGhc :: IO (ParseResult,[PosToken])
parsedFileCaseBGhc = parsedFileGhc "./test/testdata/Case/B.hs"

parsedFileMGhc :: IO (ParseResult,[PosToken])
parsedFileMGhc = parsedFileGhc "./test/testdata/M.hs"

parseFileBGhc :: RefactGhc (ParseResult, [PosToken])
parseFileBGhc = parseSourceFileGhc fileName
  where
    fileName = "./test/testdata/B.hs"

parseFileMGhc :: RefactGhc (ParseResult, [PosToken])
parseFileMGhc = parseSourceFileGhc fileName
  where
    fileName = "./test/testdata/M.hs"

parsedFileNoMod = parsedFileGhc fileName
  where
    fileName = "./test/testdata/NoMod.hs"

parsedFileDd1Ghc :: IO (ParseResult,[PosToken])
parsedFileDd1Ghc = parsedFileGhc "./test/testdata/DupDef/Dd1.hs"

comp :: RefactGhc String
comp = do
    s <- get
    modInfo@(t, toks) <- parseSourceFileGhc "./test/testdata/B.hs"

    g <- GHC.getModuleGraph
    gs <- mapM GHC.showModule g
    GHC.liftIO (putStrLn $ "modulegraph=" ++ (show gs))

    let Just tm = rsModule s
    let tm' = tm {rsStreamModified = True}
    put (s {rsModule = Just tm'})

    return (show gs)

-- ---------------------------------------------------------------------

parsedFileDeclareGhc :: IO (ParseResult,[PosToken])
parsedFileDeclareGhc = parsedFileGhc "./test/testdata/FreeAndDeclared/Declare.hs"
