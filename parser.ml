(* parser.ml *)
open Tokens
exception ParseError of string

type expr =
  | Assign of token * token * token

type header =
  | HeaderEmpty
  | HeaderSet of expr * token * header

type melody =
  | Melody of token * token

type music_sequence =
  | Note of melody * music_sequence_suc
  | Repeat of token * token * music_sequence * token * music_sequence_suc

and music_sequence_suc =
  | MusicSeqEmpty
  | MusicSeqNext of token * music_sequence

type track =
  | Play of token * token * music_sequence * token * token

type program =
  | Program of header * track * token

let next_token tokens =
  match tokens with
  | [] -> raise (ParseError "Unexpected end of input")
  | token :: rest -> (token, rest)

let rec parse_program tokens =
  let (header, tokens) = parse_header tokens in
  let (track, tokens) = parse_track tokens in
  let (end_token, tokens) = next_token tokens in
  match end_token with
  | KEYWORD "end" ->
      (Program (header, track, end_token), tokens)
  | _ ->
      raise (ParseError "Syntax error: Expected 'end' keyword")

and parse_header tokens =
  match tokens with
  | (KEYWORD "composer") :: _
  | (KEYWORD "instrument") :: _
  | (KEYWORD "bpm") :: _
  | (KEYWORD "title") :: _ ->
      let (expr, tokens) = parse_expr tokens in
      let (semicolon, tokens) = next_token tokens in
      if semicolon = SEMICOLON then
        let (header_rest, tokens) = parse_header tokens in
        (HeaderSet (expr, semicolon, header_rest), tokens)
      else
        raise (ParseError "Syntax error: Expected ';' after attribute assignment")
  | _ -> (HeaderEmpty, tokens)

and parse_expr tokens =
  let (attribute, tokens) = next_token tokens in
  match attribute with
  | KEYWORD _ ->
      let (operator, tokens) = next_token tokens in
      if operator = OPERATOR "=" then
        let (value, tokens) = next_token tokens in
        (Assign (attribute, operator, value), tokens)
      else
        raise (ParseError "Syntax error: Expected '=' operator")
  | _ ->
      raise (ParseError "Syntax error: Expected an attribute keyword")

and parse_track tokens =
  let (play_keyword, tokens) = next_token tokens in
  match play_keyword with
  | KEYWORD "play" ->
      let (lpar, tokens) = next_token tokens in
      if lpar = LPAREN then
        let (music_seq, tokens) = parse_music_sequence tokens in
        let (rparen, tokens) = next_token tokens in
        if rparen = RPAREN then
          let (semicolon, tokens) = next_token tokens in
          if semicolon = SEMICOLON then
            (Play (play_keyword, lpar, music_seq, rparen, semicolon), tokens)
          else
            raise (ParseError "Syntax error: Expected ';' after track")
        else
          raise (ParseError "Syntax error: Missing ')' after music sequence")
      else
        raise (ParseError "Syntax error: Missing '(' after 'play'")
  | _ ->
      raise (ParseError "Syntax error: Expected 'play' keyword for track")

and parse_music_sequence tokens =
  match tokens with
  | (MUSICNOTE _) :: _ ->
      let (melody, tokens) = parse_melody tokens in
      let (m_suc, tokens) = parse_music_sequence_suc tokens in
      (Note (melody, m_suc), tokens)
  | (KEYWORD "repeat") :: _ ->
      let (repeat, tokens) = next_token tokens in
      let (lpar, tokens) = next_token tokens in
      if lpar = LPAREN then
        let (inner_music_seq, tokens) = parse_music_sequence tokens in
        let (rpar, tokens) = next_token tokens in
        if rpar = RPAREN then
          let (m_suc, tokens) = parse_music_sequence_suc tokens in
          (Repeat (repeat, lpar, inner_music_seq, rpar, m_suc), tokens)
        else
          raise (ParseError "Syntax error: Expected ')' after repeat sequence")
      else
        raise (ParseError "Syntax error: Missing '(' after 'repeat'")
  | _ ->
      raise (ParseError "Syntax error: Expected a music note or 'repeat'")

and parse_music_sequence_suc tokens =
  match tokens with
  | COMMA :: _ ->
      let (comma, tokens) = next_token tokens in
      let (music_seq, tokens) = parse_music_sequence tokens in
      (MusicSeqNext (comma, music_seq), tokens)
  | _ -> (MusicSeqEmpty, tokens)

and parse_melody tokens =
  let (note_token, tokens) = next_token tokens in
  match note_token with
  | MUSICNOTE _ ->
      let (duration_token, tokens) = next_token tokens in
      (match duration_token with
       | DURATION _ ->
           (Melody (note_token, duration_token), tokens)
       | _ ->
           raise (ParseError "Syntax error: Expected a duration after the music note"))
  | _ ->
      raise (ParseError "Syntax error: Expected a music note")
