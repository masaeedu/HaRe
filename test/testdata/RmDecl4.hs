{-# LANGUAGE FlexibleContexts #-}
module RmDecl4 where

-- Remove first declaration from a where clause, rest should still be indented
ff y = y + zz ++ xx
  where
    zz = 1
    xx = 2

-- EOF
