module Config where

import Network.URI
import System.Console.GetOpt
import Control.Exception
import Text.Regex
import Distribution.Package

import Error
import MaybeRead

data HackPortOptions
	= OverlayPath String
	| Category String
	| Server String
	| TempDir String
	| Verbosity String
	| Help
        | RefreshCache

data OperationMode
	= List String
	| Merge PackageIdentifier
	| DiffTree DiffMode
	| Update
	| ShowHelp
	| OverlayOnly

data DiffMode
	= ShowAll
	| ShowMissing
	| ShowAdditions
	| ShowNewer
	| ShowCommon
	deriving Eq

data Config = Config
	{ overlayPath		::Maybe String
	, defaultPortageCategory::String
	, server		::URI
	, tmp			::String
	, verbosity		::Verbosity
        , refreshCache          ::Bool
	}

data Verbosity
	= Debug
	| Normal
	| Silent

packageRegex = mkRegex "^(.*?)-([0-9].*)$"

defaultConfig :: Config
defaultConfig = Config
	{ overlayPath = Nothing
	, defaultPortageCategory = "dev-haskell"
	, server = URI "http:" (Just $ URIAuth "" "hackage.haskell.org" "") "/packages/archive/" "" ""
	, tmp = "/tmp"
	, verbosity = Normal
        , refreshCache = False
	}

hackageOptions :: [OptDescr HackPortOptions]
hackageOptions =
	[Option ['o'] ["overlay-path"] (ReqArg OverlayPath "PATH") "The overlay tree to merge to"
	,Option ['c'] ["portage-category"] (ReqArg Category "CATEGORY") "The cateory the program belongs to"
	,Option ['s'] ["server"] (ReqArg Server "URL") "The Hackage server to query"
	,Option ['t'] ["temp-dir"] (ReqArg TempDir "PATH") "A temp directory where tarballs can be stored"
	,Option ['v'] ["verbosity"] (ReqArg Verbosity "debug|normal|silent") "Set verbosity level (default is 'normal')"
	,Option ['h', '?'] ["help"] (NoArg Help) "Display this help message"
        ,Option ['r'] ["refresh-cache"] (NoArg RefreshCache) "Refresh the hackport cache before running the command"
	]

parseConfig :: [String] -> Either String ([HackPortOptions],OperationMode)
parseConfig opts = let
	(popts,args,errs) = getOpt Permute hackageOptions opts
	mode | not (null errs) = Left $ "Error while parsing flags:\n"
	                             ++ concat errs
	     | not (null [ () | Help <- popts ]) = Right ShowHelp
	     | otherwise = case args of
		"merge":[] -> Left "Need a package's name and version to merge it.\n"
		"merge":package:[] -> case readPMaybe parsePackageId package of
			Nothing ->Left ("Could not parse '"++package++"' to a valid package. Valid packages use <name>-<version-number>-<version-postfix> where version consists only of numbers and points.\n")
			Just pid -> Right (Merge pid)
		"merge":_:rest -> Left ("'merge' takes 1 argument("++show ((length rest)+1)++" given).\n")
		"list":[] -> Right (List "")
		"list":package:[] -> Right (List package)
		"list":rest -> Left ("'list' takes at most one argument ("++show (length rest)++" given).\n")
		"diff":[] -> Right (DiffTree ShowAll)
		"diff":"all":[] -> Right (DiffTree ShowAll)
		"diff":"missing":[] -> Right (DiffTree ShowMissing)
		"diff":"additions":[] -> Right (DiffTree ShowAdditions)
		"diff":"newer":[] -> Right (DiffTree ShowNewer)
		"diff":"common":[] -> Right (DiffTree ShowCommon)
		"diff":arg:[] -> Left ("Unknown argument to 'diff': Use all,missing,additions,newer or common.\n")
		"diff":arg1:args -> Left ("'diff' takes one argument("++show ((length args)+1)++" given).\n")
		"update":[] -> Right Update
		"update":rest -> Left ("'update' takes zero arguments("++show (length rest)++" given).\n")
		"overlayonly":[] -> Right OverlayOnly
		"overlayonly":args -> Left ("'overlayonly' doesn't take any arguments. ("++show ((length args)+1)++" given).\n")
		[] -> Right ShowHelp
		_ -> Left "Unknown opertation mode\n"
	in case mode of
		Left err -> Left err
		Right mod -> Right (popts,mod)

hackageUsage :: IO ()
hackageUsage = putStr $ flip usageInfo hackageOptions $ unlines
	[ "Usage:"
	, "\t\"hackport [OPTION] MODE [MODETARGET]\""
	, "\t\"hackport [OPTION] list [PKG]\" lists all packages or packages matching search term"
	, "\t\"hackport [OPTION] merge PKG-VERSION\" merges a package into the portage tree"
	, "\t\"hackport [OPTION] diff\" prints the difference between the portage-tree and the server's packages"
	, "\t\"hackport [OPTION] update\" updates the local cache"
	, "\t\"hackport [OPTION] overlayonly\" prints all ebuilds that exist only in the overlay"
	, "Options:"
	]

parseVerbosity :: String -> Maybe Verbosity
parseVerbosity "debug" = Just Debug
parseVerbosity "normal" = Just Normal
parseVerbosity "silent" = Just Silent
parseVerbosity _ = Nothing
