port module Main exposing (main)

import Html exposing (..)
import List exposing (..)
import Html.Attributes exposing (..)
import Browser
import Html.Events exposing (..)
import Json.Decode as Decode exposing (Decoder)
import Array exposing (..)

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
  , images : Array ImageInfo
  }

sceneDecoder : Decoder Scene
sceneDecoder =
  Decode.map2 Scene
    (Decode.field "name" Decode.string)
    (Decode.field "images" (Decode.array imageDecoder))

type alias Project =
  { name : String
  , id : String
  , scenes : Array Scene
  }

projectDecoder : Decoder Project
projectDecoder =
  Decode.map3 Project
    (Decode.field "name" Decode.string)
    (Decode.field "_id" Decode.string) -- Note: mongodb _id
    (Decode.field "scenes" (Decode.array sceneDecoder))

projectsDecoder : Decoder (List Project)
projectsDecoder =
    Decode.list projectDecoder

type alias Settings =
  { cameraUrl : String
  , cameraUser : String
  , cameraPass : String
  }

asCameraUrlIn : Settings -> String -> Settings
asCameraUrlIn settings newVal =
  { settings | cameraUrl = newVal }

asCameraUserIn : Settings -> String -> Settings
asCameraUserIn settings newVal =
  { settings | cameraUser = newVal }

asCameraPassIn : Settings -> String -> Settings
asCameraPassIn settings newVal =
  { settings | cameraPass = newVal }

asSettingsIn : Model -> Settings -> Model
asSettingsIn model newSettings =
  { model | settings = newSettings }

type CurrentView 
  = SettingsView
  | ProjectsView
  | ProjectView Project Int

type alias Model = 
  { projects : List Project
  , settings : Settings
  , currentView : CurrentView
  , newProjectName : String
  }

type Msg
  = GrabImage Project Int
  | Receive String
  | ToProjectsView
  | ToSettingsView
  | ToProjectView Project Int
  | ProjectNameChanged String
  | CameraUrlChanged String
  | CameraUserChanged String
  | CameraPassChanged String
  | CreateProject
  | AddScene


init : () -> (Model, Cmd Msg)
init _ =
  ({ projects = []
   , settings =
     { cameraUrl = "http://camera/image/jpeg.cgi"
     , cameraUser = "admin"
     , cameraPass = "HDer1337"
     }
   , currentView = ProjectsView
   , newProjectName = ""
  }, Cmd.none)

actIfProjectView model fn = 
  (case model.currentView of
    ProjectView project sceneIndex -> (fn project sceneIndex)
    _ -> (model, Cmd.none)
  )

col : String -> String
col =
  (String.replace ":" "<colon>")

update : Msg -> Model -> (Model, Cmd Msg)
update msg model =
  case msg of
    GrabImage project sceneIndex ->
      (model, websocketOut ("grab-image:"++project.id++":"++(String.fromInt sceneIndex)++":"++(col model.settings.cameraUrl)++":"++(col model.settings.cameraUser)++":"++(col model.settings.cameraPass)))

    Receive jsonText ->
      let 
        newProjects = case (Decode.decodeString projectsDecoder jsonText) of 
          Ok ps -> ps
          Err _ -> []
        newView = case model.currentView of
          ProjectView project sceneIndex -> 
            let
              maybeProject = List.head (List.filter (\p -> p.id == project.id) newProjects)
            in
              case maybeProject of
                Just p -> ProjectView p sceneIndex
                _ -> ProjectsView
          other -> other
      in
        ({ model | projects = newProjects, currentView = newView }, Cmd.none)

    ToSettingsView ->
      ({ model | currentView = SettingsView }, Cmd.none)
    ToProjectsView ->
      ({ model | currentView = ProjectsView }, Cmd.none)
    ToProjectView theProject sceneIndex ->
      ({ model | currentView = ProjectView theProject sceneIndex }, Cmd.none)

    ProjectNameChanged newVal ->
      ({ model | newProjectName = newVal }, Cmd.none)
    CameraUrlChanged newVal ->
      (newVal
      |> asCameraUrlIn model.settings
      |> asSettingsIn model, Cmd.none)
    CameraUserChanged newVal ->
      (newVal
      |> asCameraUserIn model.settings
      |> asSettingsIn model, Cmd.none)
    CameraPassChanged newVal ->
      (newVal
      |> asCameraPassIn model.settings
      |> asSettingsIn model , Cmd.none)

    CreateProject ->
      (model, websocketOut ("new-project:" ++ model.newProjectName))

    AddScene -> 
      actIfProjectView model (\p si -> (model, websocketOut ("new-scene:"++p.id++":"++(String.fromInt si))))

subscriptions : Model -> Sub Msg
subscriptions model =
  websocketIn Receive


view : Model -> Html Msg
view model =
  let
    renderInput theLabel val theType changeMessage =
      div [] 
        [ label [] [ text theLabel ]
        , input [(type_ theType), (value val), (onInput changeMessage)] []
        ]
    renderSettings settings =
      Html.form [class "settings"]
        [ renderInput "Camera url" settings.cameraUrl "text" CameraUrlChanged
        , renderInput "Camera user" settings.cameraUser "text" CameraUserChanged
        , renderInput "Camera pass" settings.cameraPass "password" CameraPassChanged
        ]
    renderImage : ImageInfo -> Html Msg
    renderImage i =
      div [class "image"] [ img [(src i.path), (alt i.path), (style "height" "200px")] [] ]
    renderScene : Scene -> Html Msg
    renderScene scene =
      div [class "scene"]
        [ span [class "scene-hdr"] [(text scene.name)]
        , button [] [text "Move up"]
        , button [] [text "Move down"]
        , button [] [text "Reverse"]
        , button [] [text "Animate"]
        , button [class "red"] [text "Delete Scene"]
        , div [class "images"] (List.map renderImage (toList scene.images))
        ]
    renderProject : Project -> Int -> Html Msg
    renderProject project sceneIndex =
      div [class "project"] 
        [ div [] [ (text project.name) ]
        , button [onClick (GrabImage project sceneIndex)] [text "Take picture!"]
        , div [] (List.map renderScene (toList project.scenes))
        ]
    renderProjects : List Project -> Html Msg
    renderProjects projects =
      div [class "projects"]
        [ input [type_ "text", onInput ProjectNameChanged] []
        , button [onClick CreateProject] [text "New Project"]
        , (ul [] (List.map (\p -> (li [] [a [onClick (ToProjectView p 0), href "#"] [text p.name]])) projects))
        ]
    menuButton theLbl theMsg =
      button [onClick theMsg] [text theLbl]
  in
    div [class "app"]
      [ div [class "menu"]
        [ menuButton "Settings" ToSettingsView
        , menuButton "Projects" ToProjectsView
        ]
      , case model.currentView of
        SettingsView -> renderSettings model.settings
        ProjectsView -> renderProjects model.projects
        ProjectView p si -> renderProject p si
      ]
