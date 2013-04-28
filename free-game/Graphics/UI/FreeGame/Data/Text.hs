{-# LANGUAGE TypeSynonymInstances, FlexibleInstances, DeriveFunctor, ScopedTypeVariables #-}
module Graphics.UI.FreeGame.Data.Text where

import Data.String
import Graphics.UI.FreeGame.Base
import Graphics.UI.FreeGame.Types
import Graphics.UI.FreeGame.Internal.Finalizer
import Graphics.UI.FreeGame.Internal.Raindrop
import Graphics.UI.FreeGame.Data.Font
import Graphics.UI.FreeGame.Data.Bitmap
import Control.Monad.Free
import Control.Monad.State
import Linear

data TextF a = TypeChar Char a deriving Functor

type TextM = Free TextF

instance IsString (TextM ()) where
    fromString str = mapM_ (\c -> liftF (TypeChar c ())) str

rewrapFree :: (Functor f, Monad m) => (f (m a) -> m a) -> Free f a -> m a
rewrapFree w (Pure a) = return a
rewrapFree w (Free f) = w $ fmap (rewrapFree w) f

runTextM :: (FromFinalizer m, Monad m, Picture2D m) => Font -> BoundingBox Float -> Float -> TextM a -> m a
runTextM font bbox@(BoundingBox x0 y0 x1 y1) size = flip evalStateT (V2 x0 y0) . rewrapFree w where
    w (TypeChar ch cont) = do
        RenderedChar bmp (V2 x y) adv <- fromFinalizer $ charToBitmap font size ch
        pen :: V2 Float <- get
        let (w,h) = bitmapSize bmp
            offset = pen ^+^ V2 (x + fromIntegral w / 2) (y + fromIntegral h / 2)
        translate offset $ fromBitmap bmp
        let pen' = over _x (+adv) pen
        put $ if inBoundingBox pen' bbox 
            then pen'
            else V2 x0 (view _y pen + advV)
        cont
    advV = size * (metricsAscent font - metricsDescent font) * 1.1