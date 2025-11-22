module Main exposing (main)

import Browser
import Dict exposing (Dict)
import Html exposing (..)
import Html.Attributes exposing (attribute, class, href, placeholder, target, value)
import Html.Events exposing (onClick, onInput)
import Http
import Json.Decode as Decode exposing (Decoder)



-- MAIN


main : Program () Model Msg
main =
    Browser.element
        { init = init
        , update = update
        , subscriptions = subscriptions
        , view = view
        }



-- MODEL


type alias Model =
    { packages : Dict String Package
    , searchString : String
    , selectedPackage : Maybe String
    , selectedFilter : PackageFilter
    , status : Status
    }


type PackageFilter
    = All
    | Python
    | Postgresql


type Status
    = Loading
    | Failure String
    | Success


type alias Package =
    { version : String
    , broken : Bool
    , description : String
    , homepage : String
    , license : String
    , platforms : List String
    , category : String
    }


init : () -> ( Model, Cmd Msg )
init _ =
    ( { packages = Dict.empty
      , searchString = ""
      , selectedPackage = Nothing
      , selectedFilter = All
      , status = Loading
      }
    , Http.get
        { url = "packages.json"
        , expect = Http.expectJson GotPackages packagesDecoder
        }
    )



-- UPDATE


type Msg
    = GotPackages (Result Http.Error (Dict String Package))
    | Search String
    | SelectPackage String
    | SelectFilter PackageFilter


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        GotPackages result ->
            case result of
                Ok packages ->
                    ( { model | packages = packages, status = Success }
                    , Cmd.none
                    )

                Err error ->
                    ( { model | status = Failure (errorToString error) }
                    , Cmd.none
                    )

        Search searchString ->
            ( { model | searchString = searchString }
            , Cmd.none
            )

        SelectPackage name ->
            ( { model | selectedPackage = Just name }
            , Cmd.none
            )

        SelectFilter filter ->
            ( { model | selectedFilter = filter }
            , Cmd.none
            )


errorToString : Http.Error -> String
errorToString error =
    case error of
        Http.BadUrl url ->
            "Bad URL: " ++ url

        Http.Timeout ->
            "Request timeout"

        Http.NetworkError ->
            "Network error"

        Http.BadStatus status ->
            "Bad status: " ++ String.fromInt status

        Http.BadBody body ->
            "Bad body: " ++ body



-- SUBSCRIPTIONS


subscriptions : Model -> Sub Msg
subscriptions _ =
    Sub.none



-- VIEW


view : Model -> Html Msg
view model =
    div [ class "container-fluid" ]
        [ div [ class "row" ]
            [ div [ class "col-lg-6 border bg-light py-3 vh-100 overflow-auto" ]
                [ viewLeftPanel model ]
            , div [ class "col-lg-6 bg-dark text-white py-3 vh-100 overflow-auto" ]
                [ viewRightPanel model ]
            ]
        ]


viewLeftPanel : Model -> Html Msg
viewLeftPanel model =
    case model.status of
        Loading ->
            div [ class "text-center py-5" ]
                [ div [ class "spinner-border text-primary" ] []
                , p [ class "mt-3" ] [ text "Loading packages..." ]
                ]

        Failure error ->
            div [ class "alert alert-danger" ]
                [ h4 [] [ text "Error loading packages" ]
                , p [] [ text error ]
                ]

        Success ->
            div []
                [ h2 [ class "mb-3" ] [ text "Geospatial Nix packages" ]
                , input
                    [ class "form-control form-control-lg mb-3"
                    , placeholder "Search packages by name or description..."
                    , value model.searchString
                    , onInput Search
                    ]
                    []
                , viewFilterButtons model.selectedFilter
                , viewPackagesList model
                ]


viewFilterButtons : PackageFilter -> Html Msg
viewFilterButtons selectedFilter =
    div [ class "mb-3" ]
        [ viewFilterButton selectedFilter All "All"
        , text " "
        , viewFilterButton selectedFilter Python "Python"
        , text " "
        , viewFilterButton selectedFilter Postgresql "PostgreSQL"
        ]


viewFilterButton : PackageFilter -> PackageFilter -> String -> Html Msg
viewFilterButton selectedFilter filter label =
    let
        buttonClass =
            if selectedFilter == filter then
                "btn btn-dark"

            else
                "btn btn-secondary"
    in
    button
        [ class buttonClass
        , onClick (SelectFilter filter)
        ]
        [ text label ]


viewPackagesList : Model -> Html Msg
viewPackagesList model =
    let
        filteredPackages =
            filterPackages model.selectedFilter model.searchString model.packages

        packageCount =
            List.length filteredPackages
    in
    div []
        [ p [ class "text-muted" ]
            [ text (String.fromInt packageCount ++ " package(s) found") ]
        , div [ class "list-group" ]
            (List.map (viewPackageItem model.selectedPackage) filteredPackages)
        ]


filterPackages : PackageFilter -> String -> Dict String Package -> List ( String, Package )
filterPackages packageFilter searchString packages =
    let
        lowerSearch =
            String.toLower searchString

        matchesFilter pkg =
            case packageFilter of
                All ->
                    True

                Python ->
                    pkg.category == "python"

                Postgresql ->
                    pkg.category == "postgresql"
    in
    Dict.toList packages
        |> List.filter
            (\( name, pkg ) ->
                matchesFilter pkg
                    && (String.contains lowerSearch (String.toLower name)
                            || String.contains lowerSearch (String.toLower pkg.description)
                       )
            )
        |> List.sortBy Tuple.first


viewPackageItem : Maybe String -> ( String, Package ) -> Html Msg
viewPackageItem selectedPackage ( name, pkg ) =
    let
        isActive =
            case selectedPackage of
                Just selected ->
                    selected == name

                Nothing ->
                    False

        activeClass =
            if isActive then
                " active"

            else
                ""
    in
    button
        [ class ("list-group-item list-group-item-action" ++ activeClass)
        , onClick (SelectPackage name)
        ]
        [ div [ class "d-flex w-100 justify-content-between" ]
            [ h5 [ class "mb-1" ] [ text name ]
            , small [] [ text pkg.version ]
            ]
        , p [ class "mb-1 text-truncate" ] [ text pkg.description ]
        , if pkg.broken then
            small [ class "text-danger" ] [ text "⚠ Broken" ]

          else
            text ""
        ]


viewRightPanel : Model -> Html Msg
viewRightPanel model =
    case model.selectedPackage of
        Nothing ->
            viewInstructions

        Just name ->
            case Dict.get name model.packages of
                Just pkg ->
                    viewPackageDetails name pkg

                Nothing ->
                    viewInstructions


installNixCmd : String
installNixCmd =
    """curl --proto '=https' --tlsv1.2 -sSf \\
    -L https://install.determinate.systems/nix \\
    | sh -s -- install
"""


viewInstructions : Html Msg
viewInstructions =
    div []
        [ h2 [ class "mb-4" ] [ text "QUICK START" ]
        , div [ class "mb-4" ]
            [ p []
                [ text "Install Nix "
                , a [ href "https://zero-to-nix.com/start/install", target "_blank" ]
                    [ text "(learn more about this installer)." ]
                , pre [ class "bg-secondary p-3 rounded" ]
                    [ code [] [ text installNixCmd ] ]
                ]
            , p [] [ text "and use the search box on the left to find packages by name or description. Click on any package to view its details here." ]
            ]
        ]


viewPackageDetails : String -> Package -> Html Msg
viewPackageDetails name pkg =
    div []
        [ h2 [ class "mb-4" ] [ text name ]
        , hr [] []
        , viewDetailSection "Version" pkg.version
        , viewDetailSection "Description" pkg.description
        , if String.isEmpty pkg.homepage then
            text ""

          else
            div [ class "mb-4" ]
                [ h4 [] [ text "Homepage" ]
                , a
                    [ href pkg.homepage
                    , target "_blank"
                    , class "text-warning"
                    ]
                    [ text pkg.homepage ]
                ]
        , viewDetailSection "License" pkg.license
        , div [ class "mb-4" ]
            [ h4 [] [ text "Status" ]
            , if pkg.broken then
                span [ class "badge bg-danger" ] [ text "Broken" ]

              else
                span [ class "badge bg-success" ] [ text "Available" ]
            ]
        , hr [] []
        , div [ class "mt-5" ]
            [ h4 [] [ text "Install" ]
            , pre [ class "bg-secondary p-3 rounded" ]
                [ code [] [ text ("nix-env -iA nixpkgs." ++ name) ] ]
            ]
        ]


viewDetailSection : String -> String -> Html Msg
viewDetailSection label content =
    if String.isEmpty content then
        text ""

    else
        div [ class "mb-4" ]
            [ h4 [] [ text label ]
            , p [] [ text content ]
            ]



-- DECODERS


deriveCategoryFromName : String -> String
deriveCategoryFromName name =
    if String.startsWith "python" name then
        "python"

    else if String.startsWith "postgresql" name then
        "postgresql"

    else
        "programs"


packagesDecoder : Decoder (Dict String Package)
packagesDecoder =
    Decode.keyValuePairs packageDataDecoder
        |> Decode.map
            (\pairs ->
                List.map
                    (\( name, pkgData ) ->
                        ( name
                        , { pkgData | category = deriveCategoryFromName name }
                        )
                    )
                    pairs
                    |> Dict.fromList
            )


packageDataDecoder : Decoder Package
packageDataDecoder =
    Decode.map7 Package
        (Decode.field "version" Decode.string)
        (Decode.field "broken" Decode.bool)
        (Decode.field "description" Decode.string)
        (Decode.field "homepage" Decode.string)
        (Decode.field "license" Decode.string)
        (Decode.field "platforms" (Decode.list Decode.string))
        (Decode.succeed "")
