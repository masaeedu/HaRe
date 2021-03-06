module Renaming.D1 where

{-Rename data constructor `Tree` to `AnotherTree`.
  This refactoring affects module `D1', 'B1' and 'C1' -}

data Tree a = Leaf a | Branch (Tree a) (Tree a)

fringe :: Tree b -> [b]
fringe (Leaf x ) = [x]
fringe (Branch left right) = fringe left ++ fringe right

class SameOrNot c where
   isSame  :: c -> c -> Bool
   isNotSame :: c -> c -> Bool

instance SameOrNot Int where
   isSame d  e = d == e
   isNotSame d e = d /= e

sumSquares (x:xs) = sq x + sumSquares xs
    where sq x = x ^pow
          pow = 2

sumSquares [] = 0
