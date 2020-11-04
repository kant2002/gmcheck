{-|
Module      : Language.GML.Parser.Types
Description : GML builtin types parser

A parser for signatures of built-in function and variables. See the self-descriptive format in `data/%filename%.ty`.
-}

{-# LANGUAGE OverloadedStrings #-}

module Language.GML.Parser.Types where

import Data.Maybe (fromMaybe)
import Data.Text (Text)
import qualified Data.Map.Strict as M

import Text.Megaparsec

import Language.GML.Types
import Language.GML.Parser.Common

nametype :: Parser (Name, Type)
nametype = do
    tyName <- ident
    -- TODO: flatten
    case M.lookup tyName paramTypes of
        Just res -> do
            (subname, subtype) <- between (symbol "<") (symbol ">") nametype
            return (tyName ++ " of " ++ subname, res subtype)
        Nothing -> case M.lookup tyName types of
            Just res -> return (tyName, res)
            Nothing -> fail $ "unknown type: " ++ tyName
    where
        types = M.fromList
            [ ("void",    TVoid)
            , ("any",     TAny)
            , ("real",    TReal)
            , ("int",     TReal)
            , ("alpha",   TAlpha) --between 0 and 1
            , ("bool",    TReal)
            , ("string",  TString)
            , ("color",   TColor)
            , ("id",      TReal)
            , ("sprite",  TSprite)
            , ("sound",   TSound)
            , ("object",  TObject)
            , ("room",    TRoom)
            , ("mbutton", TReal) --FIXME: enum
            , ("vkey",    TReal) --FIXME: enum
            , ("event",   TReal) --FIXME: enum
            ]

        paramTypes = M.fromList
            [ ("array",   TArray)
            , ("array2",  TArray2)
            , ("grid",    TGrid)
            , ("list",    TList)
            , ("map",     TMap)
            , ("pqueue",  TPriorityQueue)
            , ("queue",   TQueue)
            , ("stack",   TStack)
            ]

names :: Parser [Name]
names = sepBy1 ident (symbol ",")

-- * Parsing variable types

vars :: Parser ([Name], Type)
vars = do
    names <- names <* symbol ":"
    (_, ty) <- nametype
    return (names, ty)

-- | Dictionary for holding variable types.
type VarDict = M.Map Name Type

parseVars :: String -> Text -> Result VarDict
parseVars name src = M.fromList . concatMap unpack <$>
    parseMany vars name src

-- * Parsing function signatures

arg :: Parser Argument
arg = do
    name <- optional $ brackets ident
    (tyName, ty) <- nametype
    return $ (fromMaybe tyName name, ty)

sigs :: Parser ([Name], Signature)
sigs = do
    names <- names <* symbol ":"
    rawArgs <- sepBy1 arg (symbol ",")
    let args = case rawArgs of
                    [(_, TVoid)] -> []
                    xs -> xs
    symbol "->"
    (_, ret) <- nametype
    return (names, args :-> ret)

-- | Dictionary for holding function signatures.
type FunDict = M.Map Name Signature

unpack :: ([a], b) -> [(a, b)]
unpack (xs, y) = [(x, y) | x <- xs]

parseFun :: String -> Text -> Result FunDict
parseFun name src = M.fromList . concatMap unpack <$>
    parseMany sigs name src
