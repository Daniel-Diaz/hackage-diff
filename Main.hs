
module Main (main) where

import Data.Version (showVersion)
import Data.Map qualified as Map
import Network.HTTP.Simple (httpBS, httpJSON, parseRequest, getResponseBody)
import System.Directory (listDirectory, doesFileExist, removeDirectoryRecursive, removeFile)
import System.FilePath (takeExtension, dropExtension)
import Control.Monad (filterM)
import Data.ByteString qualified as ByteString
import System.Process (callCommand)

main :: IO ()
main = do
  files <- listDirectory "." >>= filterM doesFileExist
  let cabalFiles = filter ((==) ".cabal" . takeExtension) files
  case cabalFiles of
    [] -> fail "No cabal file found."
    cabalFile : _ -> do
      let pkgName = dropExtension cabalFile
      putStrLn $ "Package name: " ++ pkgName
      req <- parseRequest $ "https://hackage.haskell.org/package/" ++ pkgName
      versionMap <- Map.filter ((==) "normal") . getResponseBody <$> httpJSON req
      case Map.lookupMax versionMap of
        Nothing -> fail "No 'normal' version found on Hackage."
        Just (v,_) -> do
          putStrLn $ "Latest version on Hackage: " ++ showVersion v
          putStrLn "Downloading tarball..."
          let tarName = pkgName ++ "-" ++ showVersion v
              tarFileName = tarName ++ ".tar.gz"
          downloadRequest <- parseRequest $
               "https://hackage.haskell.org/package/" ++ pkgName ++ "-" ++ showVersion v
            ++ "/" ++ tarFileName
          tar <- getResponseBody <$> httpBS downloadRequest
          ByteString.writeFile tarFileName tar
          putStrLn "Decompressing tarball..."
          callCommand $ "tar -xf " ++ tarFileName
          putStrLn "Diff:"
          callCommand $ "diff --color -x '" ++ tarName ++ "' -x '" ++ tarFileName
                     ++ "' -r '" ++ tarName ++ "/' . || true"
          -- Cleanup
          removeDirectoryRecursive tarName
          removeFile tarFileName
