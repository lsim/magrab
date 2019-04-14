port module Main exposing (main)

import Html exposing (..)
import List exposing (..)
import Html.Attributes exposing (..)
import Html.Keyed as Keyed
import Html.Lazy exposing (lazy)
import Browser
import Html.Events exposing (..)
import Json.Decode as Decode exposing (Decoder)
import Json.Encode as Encode
import Array exposing (..)
import Task exposing (..)
import Time exposing (..)
import Browser.Dom as Dom exposing (..)
import Process exposing (..)

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

imageEncoder : ImageInfo -> Encode.Value
imageEncoder image =
  Encode.object
    [ ("path", Encode.string image.path) ]

imageDecoder : Decoder ImageInfo
imageDecoder =
  Decode.map ImageInfo 
    (Decode.field "path" Decode.string)

type alias Scene =
  { images : Array ImageInfo }

sceneEncoder : Scene -> Encode.Value
sceneEncoder scene =
  Encode.object
    [ ("images", Encode.list imageEncoder (Array.toList scene.images)) ]

sceneDecoder : Decoder Scene
sceneDecoder =
  Decode.map Scene
    (Decode.field "images" (Decode.array imageDecoder))

type alias Project =
  { name : String
  , id : String
  , scenes : Array Scene
  }

projectEncoder : Project -> Encode.Value
projectEncoder project =
  Encode.object
    [ ("name", Encode.string project.name)
    , ("_id", Encode.string project.id)
    , ("scenes", Encode.list sceneEncoder (Array.toList project.scenes))
    ]

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

addImageToModel : Model -> String -> String -> Int -> Model
addImageToModel model imagePath projectId sceneIndex =
  case List.filter (\p -> p.id == projectId) model.projects of
    project :: _ ->
      case Array.get sceneIndex project.scenes of
        Just scene -> 
          let
            newImages = Array.push { path = imagePath } scene.images
            newScene = { scene | images = newImages }
            newScenes = Array.set sceneIndex newScene project.scenes
            newProject = { project | scenes = newScenes }
          in
            updateProject model newProject
        _ -> Debug.log "No such scene" model -- No such scene - ignore
    _ -> Debug.log "No such project" model -- No such project - ignore


type CurrentView 
  = SettingsView
  | ProjectsView
  | ProjectView Project

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
  | SaveProjects
  | MoveSceneUp Project Int
  | ReverseScene Project Int Scene
  | AnimateScene Project Int Scene
  | DeleteScene Project Int
  | NoOp


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
    ProjectView project -> (fn project)
    _ -> (model, Cmd.none)
  )

col : String -> String
col =
  (String.replace ":" "<colon>")
initiateSave : Cmd Msg
initiateSave =
  Task.perform (\_ -> SaveProjects) Time.now

updateProject : Model -> Project -> Model
updateProject model newProject =
  let
    newProjects = List.map (\p -> if p.id == newProject.id then newProject else p) model.projects
    newView = case model.currentView of
      ProjectView _ -> ProjectView newProject
      other -> other
  in
    { model | projects = newProjects, currentView = newView }
  
removeFromList : Int -> List a -> List a
removeFromList i xs =
  (List.take i xs) ++ (List.drop (i+1) xs) 

scrollToRight : String -> Cmd Msg
scrollToRight id =
  Process.sleep 700
    |> Task.andThen (\_ -> Dom.getViewportOf id)
    |> Task.andThen (\info -> Dom.setViewportOf id (Debug.log "Scrolling " info.scene.width) 0)
    |> Task.attempt (\_ -> NoOp)

update : Msg -> Model -> (Model, Cmd Msg)
update msg model =
  case msg of
    GrabImage project sceneIndex ->
      (model, websocketOut ("grab-image:"++project.id++":"++(String.fromInt sceneIndex)++":"++(col model.settings.cameraUrl)++":"++(col model.settings.cameraUser)++":"++(col model.settings.cameraPass)))

    Receive data ->
      case String.split ":" data of
        "image-grabbed" :: imagePath :: projectId :: sceneIndexString :: _ ->
          -- Add the image to the scene in the project
          let
            sceneIndex = case String.toInt sceneIndexString of
                Just i -> i
                _ -> 0
          in
          ( addImageToModel model imagePath projectId sceneIndex
          , Cmd.batch 
            [ initiateSave
            , scrollToRight ("scene-" ++ (String.fromInt sceneIndex))
            ]
          )
        "state" :: jsonString :: _ ->
          -- Parse and restore project data
          let
            safeJsonString = String.replace "<colon>" ":" jsonString
            newProjects = case (Decode.decodeString projectsDecoder safeJsonString) of 
              Ok ps -> ps
              Err err -> Debug.log ("json parsing failed"++(Decode.errorToString err)) []
            newView = case model.currentView of
              ProjectView project -> 
                case List.filter (\p -> p.id == project.id) newProjects of
                  newProject :: _ -> ProjectView newProject
                  _ -> ProjectsView
              other -> other
          in
            ({ model | projects = newProjects, currentView = newView }, Cmd.none)
        _ -> (model, Cmd.none) -- Unknown message received - ignore

    ToSettingsView ->
      ({ model | currentView = SettingsView }, Cmd.none)
    ToProjectsView ->
      ({ model | currentView = ProjectsView }, Cmd.none)
    ToProjectView theProject sceneIndex ->
      ({ model | currentView = ProjectView theProject }, Cmd.none)

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
      actIfProjectView model (\project -> 
        let
          newScenes = Array.push { images = Array.empty } project.scenes
          newProject = { project | scenes = newScenes }
        in
          (updateProject model newProject, initiateSave))

    SaveProjects ->
      (model, websocketOut ("save:"++String.replace ":" "<colon>" (Encode.encode 0 (Encode.list projectEncoder model.projects)))) -- 0 indents

    MoveSceneUp project sceneIndex ->
      let
        mbyOtherScene = Array.get (sceneIndex - 1) project.scenes
        mbyScene = Array.get sceneIndex project.scenes
        newScenes = case (mbyScene, mbyOtherScene) of
          (Just scene, Just otherScene) -> Array.set (sceneIndex - 1) scene (Array.set sceneIndex otherScene project.scenes)
          _ -> project.scenes
        newProject = { project | scenes = newScenes }
      in
        (updateProject model newProject, initiateSave)

    ReverseScene project sceneIndex scene ->
      let
        newScene = { scene | images = scene.images |> Array.toList |> List.reverse |> Array.fromList }
        newScenes = Array.set sceneIndex newScene project.scenes
        newProject = { project | scenes = newScenes }
      in
        (updateProject model newProject, initiateSave)

    AnimateScene project sceneIndex scene ->
      (model, Cmd.none) -- TODO

    DeleteScene project sceneIndex ->
      let
        newScenes = project.scenes 
          |> Array.toList 
          |> removeFromList sceneIndex 
          |> Array.fromList
        newProject = { project | scenes = newScenes }
      in
        (updateProject model newProject, initiateSave)
    
    NoOp -> (model, Cmd.none)
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
      div [class "image"] [ img [src i.path] [] ]
    renderKeyedImage : ImageInfo -> (String, Html Msg)
    renderKeyedImage i =
      (i.path, lazy renderImage i)
    renderScene : Project -> Int -> Scene -> Html Msg
    renderScene project index scene =
      div [class "scene"]
        [ span [class "scene-hdr"] [(text ("Scene " ++ String.fromInt (index+1)))]
        , button [onClick (GrabImage project index)] [text "Take picture!"]
        , button [onClick (MoveSceneUp project index)] [text "Move up"]
        , button [onClick (ReverseScene project index scene)] [text "Reverse"]
        , button [onClick (AnimateScene project index scene)] [text "Animate"]
        , button [class "red", onClick (DeleteScene project index)] [text "Delete Scene"]
        , Keyed.node "div" [class "images", id ("scene-"++(String.fromInt index))] (List.map renderKeyedImage (toList scene.images))
        ]
    renderProject : Project -> Html Msg
    renderProject project =
      div [class "project"] 
        [ div [] [ (text project.name) ]
        , button [onClick AddScene] [text "Add scene"]
        , div [] (List.indexedMap (renderScene project) (toList project.scenes))
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
        SettingsView -> lazy renderSettings model.settings
        ProjectsView -> lazy renderProjects model.projects
        ProjectView p -> lazy renderProject p
      ]
