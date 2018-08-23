{-# LANGUAGE DeriveFunctor, DeriveFoldable, DeriveTraversable, TypeFamilies #-}
-----------------------------------------------------------------------------
-- |
-- Module     : Algebra.Graph.Labelled
-- Copyright  : (c) Andrey Mokhov 2016-2018
-- License    : MIT (see the file LICENSE)
-- Maintainer : andrey.mokhov@gmail.com
-- Stability  : experimental
--
-- __Alga__ is a library for algebraic construction and manipulation of graphs
-- in Haskell. See <https://github.com/snowleopard/alga-paper this paper> for the
-- motivation behind the library, the underlying theory, and implementation details.
--
-- This module defines edge-labelled graphs.
--
-----------------------------------------------------------------------------
module Algebra.Graph.Labelled (
    -- * Algebraic data type for edge-labeleld graphs
    Dioid (..), Graph (..), UnlabelledGraph, overlay, connect, lconnect,
    (-<), (>-),

    -- * Distances
    Distance (..),

    -- * Operations
    edgeLabel
  ) where

import Prelude ()
import Prelude.Compat
import GHC.Exts

import qualified Algebra.Graph.Class as C
import qualified Data.Set as Set

-- | A bounded join semilattice, satisfying the following laws:
--
--   Commutativity:         x \/ y == y \/ x
--   Associativity:  x \/ (y \/ z) == (x \/ y) \/ z
--   Identity:           x \/ zero == x
--   Idempotence:           x \/ x == x
--
class Semilattice a where
    zero :: a
    (\/) :: a -> a -> a

-- | Dioid is an idempotent semiring:
--
--     Associativity:  x /\ (y /\ z) == (x /\ y) /\ z
--     Identity:            x /\ one == x
--                          one /\ x == x
--     Annihilating zero:  x /\ zero == zero
--                         zero /\ x == zero
--
--     Distributivity: x /\ (y \/ z) == x /\ y \/ x /\ z
--                     (x \/ y) /\ z == x /\ z \/ y /\ z
--
class Semilattice a => Dioid a where
    one  :: a
    (/\) :: a -> a -> a

infixl 6 \/
infixl 7 /\

-- Type variable e stands for edge labels
data Graph e a = Empty
               | Vertex a
               | Connect e (Graph e a) (Graph e a)
               deriving (Foldable, Functor, Show, Traversable)

overlay :: Semilattice e => Graph e a -> Graph e a -> Graph e a
overlay = Connect zero

connect :: Dioid e => Graph e a -> Graph e a -> Graph e a
connect = Connect one

lconnect :: e -> Graph e a -> Graph e a -> Graph e a
lconnect = Connect

-- Convenient ternary-ish operator x -<e>- y, for example:
-- x = Vertex "x"
-- y = Vertex "y"
-- z = x -<1>- y
(-<) :: Graph e a -> e -> (Graph e a, e)
g -< e = (g, e)

(>-) :: (Graph e a, e) -> Graph e a -> Graph e a
(g, e) >- h = Connect e g h

infixl 5 -<
infixl 5 >-

-- TODO: Prove the C.Graph laws
instance Dioid e => C.Graph (Graph e a) where
    type Vertex (Graph e a) = a
    empty   = Empty
    vertex  = Vertex
    overlay = overlay
    connect = connect

edgeLabel :: (Eq a, Semilattice e) => a -> a -> Graph e a -> e
edgeLabel _ _ Empty           = zero
edgeLabel _ _ (Vertex _)      = zero
edgeLabel x y (Connect e g h) = edgeLabel x y g \/ edgeLabel x y h \/ new
  where
    new | x `elem` g && y `elem` h = e
        | otherwise                = zero

instance Semilattice Bool where
    zero  = False
    (\/) = (||)

instance Dioid Bool where
    one   = True
    (/\) = (&&)

-- TODO: Prove that this is identical to Algebra.Graph
type UnlabelledGraph a = Graph Bool a

data Distance a = Finite a | Infinite deriving (Eq, Ord, Show)

instance (Ord a, Num a) => Num (Distance a) where
    fromInteger = Finite . fromInteger

    Infinite + _ = Infinite
    _ + Infinite = Infinite
    Finite x + Finite y = Finite (x + y)

    Infinite * _ = Infinite
    _ * Infinite = Infinite
    Finite x * Finite y = Finite (x * y)

    negate _ = error "Negative distances not allowed"

    signum (Finite 0) = 0
    signum _ = 1

    abs = id

instance Ord a => Semilattice (Distance a) where
    zero = Infinite

    Infinite \/ x = x
    x \/ Infinite = x
    Finite x \/ Finite y = Finite (min x y)

instance (Num a, Ord a) => Dioid (Distance a) where
    one  = Finite 0

    Infinite /\ _ = Infinite
    _ /\ Infinite = Infinite
    Finite x /\ Finite y = Finite (x + y)

instance Ord a => Semilattice (Maybe a) where
    zero = Nothing

    Nothing \/ x = x
    x \/ Nothing = x
    Just x \/ Just y = Just (min x y)

instance (Num a, Ord a) => Dioid (Maybe a) where
    one  = Just 0

    Nothing /\ _ = Nothing
    _ /\ Nothing = Nothing
    Just x /\ Just y = Just (x + y)

data Set a = Set (Set.Set a) | Universe

instance (Bounded a, Enum a, Ord a) => IsList (Set a) where
    type Item (Set a) = a
    fromList = Set . Set.fromList

    toList (Set s)  = Set.toList s
    toList Universe = [minBound..maxBound]

instance Ord a => Semilattice (Set a) where
    zero = Set Set.empty

    Universe \/ _  = Universe
    _ \/ Universe  = Universe
    Set x \/ Set y = Set (Set.union x y)

instance Ord a => Dioid (Set a) where
    one  = Universe

    Universe /\ x  = x
    x /\ Universe  = x
    Set x /\ Set y = Set (Set.intersection x y)
