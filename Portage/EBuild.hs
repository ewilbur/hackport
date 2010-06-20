module Portage.EBuild
        ( EBuild(..)
        , ebuildTemplate
        ) where

import Distribution.Text ( Text(..), display )
import qualified Text.PrettyPrint as Disp

import Portage.Dependency
import Portage.Version
import Portage.PackageId

import Distribution.License as Cabal

data EBuild = EBuild {
    name :: String,
    version :: String,
    description :: String,
    homepage :: String,
    src_uri :: String,
    license :: Cabal.License,
    slot :: String,
    keywords :: [String],
    iuse :: [String],
    haskell_deps :: [Dependency],
    build_tools :: [Dependency],
    extra_libs :: [Dependency],
    cabal_dep :: Dependency,
    ghc_dep :: Dependency,
    depend :: [String],
    rdepend :: [String],
    features :: [String],
    my_pn :: Maybe String --If the package's name contains upper-case
  }

ebuildTemplate :: EBuild
ebuildTemplate = EBuild {
    name = "foobar",
    version = "0.1",
    description = "",
    homepage = "",
    src_uri = "",
    license = Cabal.UnknownLicense "xxx UNKNOWN xxx",
    slot = "0",
    keywords = ["~amd64","~x86"],
    iuse = [],
    haskell_deps = [],
    build_tools = [],
    extra_libs = [],
    cabal_dep = AnyVersionOf (mkPackageName "dev-haskell" "cabal"),
    ghc_dep = defaultDepGHC,
    depend = [],
    rdepend = [],
    features = [],
    my_pn = Nothing
  }

defaultDepGHC :: Dependency
defaultDepGHC = OrLaterVersionOf (Version [6,8,1] Nothing [] 0) (mkPackageName "dev-lang" "ghc")

instance Text EBuild where
  disp = Disp.text . showEBuild

showEBuild :: EBuild -> String
showEBuild ebuild =
  ss "# Copyright 1999-2010 Gentoo Foundation". nl.
  ss "# Distributed under the terms of the GNU General Public License v2". nl.
  ss "# $Header:  $". nl.
  nl.
  ss "CABAL_FEATURES=". quote' (sepBy " " $ features ebuild). nl.
  ss "inherit haskell-cabal". nl.
  nl.
  (case my_pn ebuild of
     Nothing -> id
     Just pn -> ss "MY_PN=". quote pn. nl.
                ss "MY_P=". quote "${MY_PN}-${PV}". nl. nl).
  ss "DESCRIPTION=". quote (description ebuild). nl.
  ss "HOMEPAGE=". quote (homepage ebuild). nl.
  ss "SRC_URI=". quote (replaceVars (src_uri ebuild)).
     (if null (src_uri ebuild) then ss "\t#Fixme: please fill in manually"
         else id). nl.
  nl.
  ss "LICENSE=". quote (convertLicense . license $ ebuild).
     (if null (licenseComment . license $ ebuild) then id
         else ss "\t#". ss (licenseComment . license $ ebuild)). nl.
  ss "SLOT=". quote (slot ebuild). nl.
  ss "KEYWORDS=". quote' (sepBy " " $ keywords ebuild).nl.
  ss "IUSE=". quote' (sepBy ", " $ iuse ebuild). nl.
  nl.
  ( if (not . null . build_tools $ ebuild)
      then ss "BUILDTOOLS=". quote' (sepBy "\n\t\t" $ map display $ build_tools ebuild). nl
      else id
  ).
  ( if (not . null . extra_libs $ ebuild )
      then ss "EXTRALIBS=". quote' (sepBy "\n\t\t" $ map display $ extra_libs ebuild). nl
      else id
  ).
  ( if (not . null . haskell_deps $ ebuild)
      then ss "HASKELLDEPS=". quote' (sepBy "\n\t\t" $ map display $ haskell_deps ebuild). nl
      else id
  ).
  ss "RDEPEND=". quote' (sepBy "\n\t\t" $ rdepend ebuild). nl.
  ss "DEPEND=". quote' (sepBy "\n\t\t" $ depend ebuild). nl.
  (case my_pn ebuild of
     Nothing -> id
     Just _ -> nl. ss "S=". quote ("${WORKDIR}/${MY_P}"). nl)
  $ []
  where replaceVars = replaceCommonVars (name ebuild) (my_pn ebuild) (version ebuild)

ss :: String -> String -> String
ss = showString

sc :: Char -> String -> String
sc = showChar

nl :: String -> String
nl = sc '\n'

quote :: String -> String -> String
quote str = sc '"'. ss str. sc '"'

quote' :: (String -> String) -> String -> String
quote' str = sc '"'. str. sc '"'

sepBy :: String -> [String] -> ShowS
sepBy _ []     = id
sepBy _ [x]    = ss x
sepBy s (x:xs) = ss x. ss s. sepBy s xs

getRestIfPrefix ::
	String ->	-- ^ the prefix
	String ->	-- ^ the string
	Maybe String
getRestIfPrefix (p:ps) (x:xs) = if p==x then getRestIfPrefix ps xs else Nothing
getRestIfPrefix [] rest = Just rest
getRestIfPrefix _ [] = Nothing

subStr ::
	String ->	-- ^ the search string
	String ->	-- ^ the string to be searched
	Maybe (String,String)  -- ^ Just (pre,post) if string is found
subStr sstr str = case getRestIfPrefix sstr str of
	Nothing -> if null str then Nothing else case subStr sstr (tail str) of
		Nothing -> Nothing
		Just (pre,post) -> Just (head str:pre,post)
	Just rest -> Just ([],rest)

replaceMultiVars ::
	[(String,String)] ->	-- ^ pairs of variable name and content
	String ->		-- ^ string to be searched
	String 			-- ^ the result
replaceMultiVars [] str = str
replaceMultiVars whole@((pname,cont):rest) str = case subStr cont str of
	Nothing -> replaceMultiVars rest str
	Just (pre,post) -> (replaceMultiVars rest pre)++pname++(replaceMultiVars whole post)

replaceCommonVars ::
	String ->	-- ^ PN
	Maybe String ->	-- ^ MYPN
	String ->	-- ^ PV
	String ->	-- ^ the string to be replaced
	String
replaceCommonVars pn mypn pv str
	= replaceMultiVars
		([("${P}",pn++"-"++pv)]
		++ maybe [] (\x->[("${MY_P}",x++"-"++pv)]) mypn
		++[("${PN}",pn)]
		++ maybe [] (\x->[("${MY_PN}",x)]) mypn
		++[("${PV}",pv)]) str


-- map the cabal license type to the gentoo license string format
convertLicense :: Cabal.License -> String
convertLicense (Cabal.GPL mv)     = "GPL-" ++ (maybe "2" display mv)  -- almost certainly version 2
convertLicense (Cabal.LGPL mv)    = "LGPL-" ++ (maybe "2.1" display mv) -- probably version 2.1
convertLicense Cabal.BSD3         = "BSD"
convertLicense Cabal.BSD4         = "BSD-4"
convertLicense Cabal.PublicDomain = "public-domain"
convertLicense Cabal.AllRightsReserved = ""
convertLicense Cabal.MIT          = "MIT"
convertLicense _                  = ""

licenseComment :: Cabal.License -> String
licenseComment Cabal.AllRightsReserved =
  "Note: packages without a license cannot be included in portage"
licenseComment Cabal.OtherLicense =
  "Fixme: \"OtherLicense\", please fill in manually"
licenseComment _ = ""
