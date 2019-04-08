port module Main exposing (main)

import Html exposing (..)
import Html.Attributes exposing (..)
import Browser
import Html.Events exposing (..)
import Json.Decode as Decode exposing (Decoder)

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

type alias ImageInfo =
  { path : String
  }

imageDecoder : Decoder ImageInfo
imageDecoder =
  Decode.map ImageInfo 
    (Decode.field "path" Decode.string)

type alias Scene =
  { name : String
  , images : List ImageInfo
  }

sceneDecoder : Decoder Scene
sceneDecoder =
  Decode.map2 Scene
    (Decode.field "name" Decode.string)
    (Decode.field "images" (Decode.list imageDecoder))

type alias Project =
  { name : String
  , id : String
  , scenes : List Scene
  }

projectDecoder : Decoder Project
projectDecoder =
  Decode.map3 Project
    (Decode.field "name" Decode.string)
    (Decode.field "id" Decode.string)
    (Decode.field "scenes" (Decode.list sceneDecoder))

projectsDecoder : Decoder (List Project)
projectsDecoder =
    Decode.list projectDecoder

type alias Settings =
  { cameraUrl : String
  , cameraUser : String
  , cameraPass : String
  }

type CurrentView 
  = SettingsView
  | ProjectsView
  | ProjectView Project

type alias Model = 
  { projects : List Project
  , settings : Settings
  , currentView : CurrentView
  }

type Msg
  = GrabImage
  | RequestProjects
  | Receive String
  | ToProjectsView
  | ToSettingsView
  | ToProjectView Project


init : () -> (Model, Cmd Msg)
init _ =
  ({ projects = []
   , settings =
     { cameraUrl = "http://camera/image/jpeg.cgi"
     , cameraUser = "admin"
     , cameraPass = "HDer1337"
     }
   , currentView = ProjectsView
  }, Cmd.none)

update : Msg -> Model -> (Model, Cmd Msg)
update msg model =
  case msg of
    GrabImage ->
      (model, websocketOut "grab-image")
    RequestProjects ->
      (model, websocketOut "get-projects")
    Receive jsonText ->
      let 
        newProjects = case (Decode.decodeString projectsDecoder jsonText) of 
          Ok ps -> ps
          Err _ -> []
      in
        ({ model | projects = newProjects }, Cmd.none)

    ToSettingsView ->
      ({ model | currentView = SettingsView }, Cmd.none)
    ToProjectsView ->
      ({ model | currentView = ProjectsView }, Cmd.none)
    ToProjectView theProject ->
      ({ model | currentView = ProjectView theProject }, Cmd.none)


subscriptions : Model -> Sub Msg
subscriptions model =
  websocketIn Receive


view : Model -> Html Msg
view model =
  let
    renderInput theLabel val theType =
      div [] 
        [ label [] [ text theLabel ]
        , input [(type_ theType), (value val)] []
        ]
    renderSettings settings =
      div []
        [ renderInput "Camera url" settings.cameraUrl "text"
        , renderInput "Camera user" settings.cameraUser "text"
        , renderInput "Camera pass" settings.cameraPass "password"
        ]
    renderImage i =
      div [] [ img [(src i.path), (alt i.path)] [] ]
    renderScene scene =
      div [] 
        [ div [] [ (text scene.name) ]
        , div [] (List.map renderImage scene.images)
        ]
    renderProject project =
      div [] 
        [ div [] [ (text project.name) ]
        , div [] (List.map renderScene project.scenes)
        ]
    renderProjects projects =
      ul []
        (List.map (\p -> (li [onClick (ToProjectView p)] [text p.name])) projects)
    menuButton theLbl theMsg =
      button [onClick theMsg] [text theLbl]
  in
    div []
      [ div []
        [ menuButton "Settings" ToSettingsView
        , menuButton "Projects" ToProjectsView
        ]
      , case model.currentView of
        SettingsView -> renderSettings model.settings
        ProjectsView -> renderProjects model.projects
        ProjectView p -> renderProject p
      , button [onClick GrabImage] [text "Take picture!"]
      ]
