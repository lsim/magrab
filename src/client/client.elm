port module Main exposing (main)

import Html exposing (..)
import Browser
import Html.Events exposing (..)

-- JavaScript usage: app.ports.websocketIn.send(response);
port websocketIn : (String -> msg) -> Sub msg
-- JavaScript usage: app.ports.websocketOut.subscribe(handler);
port websocketOut : String -> Cmd msg


--main : Program Never
main =
  Browser.element
    { init = init
    , view = view
    , update = update
    , subscriptions = subscriptions
    }


type alias Model = List String

type Msg
  = Send
  | Receive String


init : () -> (Model, Cmd Msg)
init _ =
  (["Welcome!"], Cmd.none)


update : Msg -> Model -> (Model, Cmd Msg)
update msg model =
  case msg of
    Send ->
      (model, websocketOut "Hello, server!")

    Receive message ->
      ((List.append model [message]), Cmd.none)


subscriptions : Model -> Sub Msg
subscriptions model =
  websocketIn Receive


view : Model -> Html Msg
view model =
  let
    renderMessage msg =
      div [] [ text msg ]
  in
    div []
      [ div [] (List.map renderMessage model)
      , button [onClick Send] [text "Send message to server!"]
      ]