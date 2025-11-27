module Main exposing (main)

import Browser
import Dict exposing (Dict)
import Html exposing (..)
import Html.Attributes exposing (attribute, class, disabled, href, placeholder, src, style, target, value)
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
    , currentPage : Int
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
    , category : String
    , recipe : String
    }


init : () -> ( Model, Cmd Msg )
init _ =
    ( { packages = Dict.empty
      , searchString = ""
      , selectedPackage = Nothing
      , selectedFilter = All
      , status = Loading
      , currentPage = 1
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
    | ChangePage Int


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
            ( { model | searchString = searchString, currentPage = 1 }
            , Cmd.none
            )

        SelectPackage name ->
            ( { model | selectedPackage = Just name }
            , Cmd.none
            )

        SelectFilter filter ->
            ( { model | selectedFilter = filter, currentPage = 1 }
            , Cmd.none
            )

        ChangePage page ->
            ( { model | currentPage = page }
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
            [ div [ class "col-lg-12 py-2" ]
                [ viewMenuPanel ]
            ]
        , div [ class "row" ]
            [ div [ class "col-lg-6 border bg-light py-3 vh-100 overflow-auto" ]
                [ viewLeftPanel model ]
            , div [ class "col-lg-6 bg-dark text-white py-3 vh-100 overflow-auto" ]
                [ viewRightPanel model ]
            ]
        ]


viewMenuPanel : Html Msg
viewMenuPanel =
    div [ class "d-flex flex-wrap align-items-center gap-2" ]
        [ h1 [ class "me-4 mb-0 fw-bold" ] [ text "GEOSPATIAL NIX" ]
        , a
            [ href "https://nixos.org/community/teams/geospatial/"
            , target "_blank"
            , class "btn btn-outline-dark"
            ]
            [ text "Geospatial Team" ]
        , a
            [ href "https://github.com/orgs/NixOS/projects/47"
            , target "_blank"
            , class "btn btn-outline-dark"
            ]
            [ text "Project Board" ]
        , a
            [ href "https://repology.org/projects/?maintainer=ivan.mincik%40gmail.com&inrepo=nix_unstable&vulnerable=on"
            , target "_blank"
            , class "btn btn-outline-dark"
            ]
            [ text "Vulnerable Packages" ]
        , a
            [ href "https://repology.org/projects/?maintainer=ivan.mincik%40gmail.com&inrepo=nix_unstable&outdated=1"
            , target "_blank"
            , class "btn btn-outline-dark"
            ]
            [ text "Outdated Packages" ]
        , a
            [ href "https://github.com/imincik/nix-utils/actions/workflows/hydra-build-status-linux.yml"
            , target "_blank"
            , class "btn btn-outline-dark"
            ]
            [ text "Hydra Status" ]
        , a
            [ href "https://nixpkgs-update-logs.nix-community.org/~supervisor/queue.html"
            , target "_blank"
            , class "btn btn-outline-dark"
            ]
            [ text "Update Queue" ]
        , a
            [ href "https://search.nixos.org/packages"
            , target "_blank"
            , class "btn btn-outline-dark"
            ]
            [ text "Nixpkgs Search" ]
        , a
            [ href "https://search.nixos.org/options"
            , target "_blank"
            , class "btn btn-outline-dark"
            ]
            [ text "Options Search" ]
        , a
            [ href "https://github.com/NixOS/nixpkgs/blob/master/CONTRIBUTING.md"
            , target "_blank"
            , class "btn btn-outline-dark"
            ]
            [ text "Contributing" ]
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
                [ input
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

        itemsPerPage =
            10

        totalPages =
            ceiling (toFloat packageCount / toFloat itemsPerPage)

        startIndex =
            (model.currentPage - 1) * itemsPerPage

        currentPagePackages =
            filteredPackages
                |> List.drop startIndex
                |> List.take itemsPerPage
    in
    div []
        [ p [ class "text-muted" ]
            [ text (String.fromInt packageCount ++ " package(s) found") ]
        , div [ class "list-group" ]
            (List.map (viewPackageItem model.selectedPackage) currentPagePackages)
        , viewPagination model.currentPage totalPages
        ]


viewPagination : Int -> Int -> Html Msg
viewPagination currentPage totalPages =
    if totalPages <= 1 then
        text ""

    else
        div [ class "d-flex justify-content-center align-items-center gap-2 mt-3" ]
            [ button
                [ class "btn btn-outline-dark btn-sm"
                , onClick (ChangePage (currentPage - 1))
                , disabled (currentPage <= 1)
                ]
                [ text "Previous" ]
            , span [ class "text-muted" ]
                [ text ("Page " ++ String.fromInt currentPage ++ " of " ++ String.fromInt totalPages) ]
            , button
                [ class "btn btn-outline-dark btn-sm"
                , onClick (ChangePage (currentPage + 1))
                , disabled (currentPage >= totalPages)
                ]
                [ text "Next" ]
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
            , small [] [ text ("v" ++ pkg.version) ]
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


viewInstructions : Html Msg
viewInstructions =
    div []
        [ div [ class "mb-4" ]
            [ p []
                [ a
                    [ href "https://github.com/imincik/nix-utils/actions/workflows/hydra-build-status-linux.yml"
                    , target "_blank"
                    ]
                    [ img
                        [ src "https://github.com/imincik/nix-utils/actions/workflows/hydra-build-status-linux.yml/badge.svg"
                        , class "me-2"
                        , style "height" "30px"
                        ]
                        []
                    ]
                , a
                    [ href "https://github.com/imincik/nix-utils/actions/workflows/hydra-build-status-darwin.yml"
                    , target "_blank"
                    ]
                    [ img
                        [ src "https://github.com/imincik/nix-utils/actions/workflows/hydra-build-status-darwin.yml/badge.svg"
                        , style "height" "30px"
                        ]
                        []
                    ]
                ]
            , hr [] []
            , p []
                [ text "This website is NOT an official Geospatial Team project. It was made by "
                , a
                    [ href "https://github.com/imincik", target "_blank" ]
                    [ text "Ivan Mincik (@imincik), " ]
                , text "a member of the Geospatial Team. Report issues or submit PRs in "
                , a
                    [ href "https://github.com/imincik/geospatial-nix-page", target "_blank" ]
                    [ text "https://github.com/imincik/geospatial-nix-page ." ]
                ]
            ]
        ]


recipeToGithubUrl : String -> String
recipeToGithubUrl recipePath =
    "https://github.com/NixOS/nixpkgs/blob/master/" ++ recipePath


viewPackageDetails : String -> Package -> Html Msg
viewPackageDetails name pkg =
    div []
        [ h2 [ class "mb-4" ] [ text (name ++ " - v" ++ pkg.version) ]
        , hr [] []
        , viewDetailSection "Description" pkg.description
        , if String.isEmpty pkg.homepage then
            text ""

          else
            div []
                [ h4 [] [ text "Homepage" ]
                , p []
                    [ a
                        [ href pkg.homepage
                        , target "_blank"
                        , class "text-warning"
                        ]
                        [ text pkg.homepage ]
                    ]
                , hr [] []
                ]
        , viewDetailSection "License" pkg.license
        , div []
            [ h4 [] [ text "Status" ]
            , p []
                [ if pkg.broken then
                    span [ class "badge bg-danger" ] [ text "Broken" ]

                  else
                    span [ class "badge bg-success" ] [ text "Available" ]
                ]
            , hr [] []
            ]
        , div []
            [ h4 [] [ text "Recipe" ]
            , p []
                [ a
                    [ href (recipeToGithubUrl pkg.recipe)
                    , target "_blank"
                    , class "text-warning"
                    ]
                    [ text pkg.recipe ]
                ]
            , hr [] []
            ]
        , div []
            [ h4 [] [ text "Hydra build" ]
            , ul []
                [ li []
                    [ a
                        [ href ("https://hydra.nixos.org/job/nixpkgs/trunk/" ++ name ++ ".x86_64-linux")
                        , target "_blank"
                        , class "text-warning"
                        ]
                        [ text "x86_64-linux" ]
                    ]
                , li []
                    [ a
                        [ href ("https://hydra.nixos.org/job/nixpkgs/trunk/" ++ name ++ ".aarch64-linux")
                        , target "_blank"
                        , class "text-warning"
                        ]
                        [ text "aarch64-linux" ]
                    ]
                , li []
                    [ a
                        [ href ("https://hydra.nixos.org/job/nixpkgs/trunk/" ++ name ++ ".x86_64-darwin")
                        , target "_blank"
                        , class "text-warning"
                        ]
                        [ text "x86_64-darwin" ]
                    ]
                , li []
                    [ a
                        [ href ("https://hydra.nixos.org/job/nixpkgs/trunk/" ++ name ++ ".aarch64-darwin")
                        , target "_blank"
                        , class "text-warning"
                        ]
                        [ text "aarch64-darwin" ]
                    ]
                ]
            , hr [] []
            ]
        , div []
            [ h4 [] [ text "Update log" ]
            , p []
                [ a
                    [ href ("https://nixpkgs-update-logs.nix-community.org/" ++ name ++ "/")
                    , target "_blank"
                    , class "text-warning"
                    ]
                    [ text ("https://nixpkgs-update-logs.nix-community.org/" ++ name ++ "/") ]
                ]
            , hr [] []
            ]

        -- , div []
        --     [ h3 [] [ text "USAGE" ]
        --     , pre [ class "bg-secondary p-3 rounded" ]
        --         [ code [] [ text ("TODO: " ++ name) ] ]
        --     ]
        ]


viewDetailSection : String -> String -> Html Msg
viewDetailSection label content =
    if String.isEmpty content then
        text ""

    else
        div []
            [ h4 [] [ text label ]
            , p [] [ text content ]
            , hr [] []
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
        (Decode.succeed "")
        (Decode.field "recipe" Decode.string)
