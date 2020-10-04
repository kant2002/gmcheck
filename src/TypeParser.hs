{-# LANGUAGE OverloadedStrings #-}

module TypeParser where

import Data.Maybe (fromMaybe)
import Data.Text (Text)
import Data.Void (Void)
import qualified Data.Map.Strict as M

import Text.Megaparsec
import Text.Megaparsec.Char
import qualified Text.Megaparsec.Char.Lexer as L

import AST (Name)
import Types

type Parser = Parsec Void Text
type Error = ParseErrorBundle Text Void

{-| Spaces and comments skipper. -}
sc :: Parser ()
sc = L.space space1 (L.skipLineComment "//") (L.skipBlockComment "/*" "*/")

lexeme :: Parser a -> Parser a
lexeme = L.lexeme sc

symbol :: Text -> Parser Text
symbol = L.symbol sc

nametype :: Parser (Name, Type)
nametype = do
    tyName <- ident
    if tyName == "array" then do
        (subname, subtype) <- between (symbol "<") (symbol ">") nametype
        return ("array of" ++ subname, TArray subtype)
    else case M.lookup tyName types of
        Just res -> return (tyName, res)
        Nothing -> fail $ "unknown type: " ++ tyName
    where
        types = M.fromList
            [ ("void",    TVoid)
            , ("real",    TReal)
            , ("int",     TReal)
            , ("alpha",   TReal) --between 0 and 1
            , ("bool",    TReal)
            , ("string",  TString)
            , ("color",   TColor)
            , ("id",      TReal)
            , ("sprite",  TId RSprite)
            , ("sound",   TId RSound)
            , ("object",  TId RObject)
            , ("room",    TId RRoom)
            , ("mbutton", TReal) --FIXME: enum
            , ("vkey",    TReal) --FIXME: enum
            , ("event",   TReal) --FIXME: enum
            ]

ident :: Parser Name
ident = lexeme $ (:) <$> letterChar <*> many (alphaNumChar <|> char '_')

names :: Parser [Name]
names = sepBy1 ident (symbol ",")

parens, brackets :: Parser a -> Parser a
parens = between (symbol "(") (symbol ")")
brackets = between (symbol "[") (symbol "]")

-- * Parsing variable types

vars :: Parser ([Name], Type)
vars = do
    names <- names <* symbol ":"
    (_, ty) <- nametype
    return (names, ty)

-- | Dictionary for holding variable types.
type VarDict = M.Map Name Type

parseVars :: String -> Text -> Either Error VarDict
parseVars name src = M.fromList . concatMap unpack <$>
    parse (sc *> many vars <* eof) name src

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

parseFun :: String -> Text -> Either Error FunDict
parseFun name src = M.fromList . concatMap unpack <$>
    parse (sc *> many sigs <* eof) name src