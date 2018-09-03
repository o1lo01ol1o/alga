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
    Dioid (..), Graph (..), UnlabelledGraph, empty, vertex, edge, overlay,
    connect, connectBy, (-<), (>-),

    -- * Distances
    Distance (..),

    -- * Operations
    edgeLabel
  ) where

import Prelude ()
import Prelude.Compat
import Data.Set (Set)

import qualified Algebra.Graph.Class as C
import qualified Data.Set as Set

-- | A bounded join semilattice, satisfying the following laws:
--
-- * Commutativity:         x \/ y == y \/ x
-- * Associativity:  x \/ (y \/ z) == (x \/ y) \/ z
-- * Identity:           x \/ zero == x
-- * Idempotence:           x \/ x == x
--
class Semilattice a where
    zero :: a
    (\/) :: a -> a -> a

-- | Dioid is an idempotent semiring:
--
-- *   Associativity:  x /\ (y /\ z) == (x /\ y) /\ z
-- *   Identity:            x /\ one == x
--                          one /\ x == x
-- *   Annihilating zero:  x /\ zero == zero
--                         zero /\ x == zero
--
-- *   Distributivity: x /\ (y \/ z) == x /\ y \/ x /\ z
--                     (x \/ y) /\ z == x /\ z \/ y /\ z
--
class Semilattice a => Dioid a where
    one  :: a
    (/\) :: a -> a -> a

infixl 6 \/
infixl 7 /\

-- This class has usual semiring laws:
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
class Dioid a where
    zero  :: a
    one   :: a
    (|+|) :: a -> a -> a
    (|*|) :: a -> a -> a

infixl 6 |+|
infixl 7 |*|

-- Type variable @e@ stands for edge labels.
data Graph e a = Empty
               | Vertex a
               | LConnect e (Graph e a) (Graph e a)
               deriving (Foldable, Functor, Show, Traversable)

overlay :: Semilattice e => Graph e a -> Graph e a -> Graph e a
overlay = Connect zero

connect :: Dioid e => Graph e a -> Graph e a -> Graph e a
connect = LConnect one

lconnect :: e -> Graph e a -> Graph e a -> Graph e a
lconnect = Connect

-- Convenient ternary-ish operator x -<e>- y, for example:
-- x = Vertex "x"
-- y = Vertex "y"
-- z = x -<1>- y
(-<) :: Graph e a -> e -> (Graph e a, e)
g -< e = (g, e)

(>-) :: (Graph e a, e) -> Graph e a -> Graph e a
(g, e) >- h = LConnect e g h

infixl 5 -<
infixl 5 >-

-- TODO: Prove the C.Graph laws
instance Dioid e => C.Graph (Graph e a) where
    type Vertex (Graph e a) = a
    empty   = Empty
    vertex  = Vertex
    overlay = overlay
    connect = connect

edgeLabel :: (Eq a, Dioid e) => a -> a -> Graph e a -> e
edgeLabel _ _ Empty            = zero
edgeLabel _ _ (Vertex _)       = zero
edgeLabel x y (LConnect e g h) = edgeLabel x y g |+| edgeLabel x y h |+| new
  where
    new | x `elem` g && y `elem` h = e
        | otherwise                = zero

instance Semilattice Bool where
    zero = False
    (\/) = (||)

instance Dioid Bool where
    one  = True
    (/\) = (&&)

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

instance Ord a => Semilattice (Set a) where
    zero = Set.empty
    (\/) = Set.union
